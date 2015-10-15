#!/bin/bash

setup_network() {
    if ! wget -q --spider http://google.com
    then

        
        if ethernet=$(ip link | grep -oiP 'enp[a-z0-9]+')
        then
            #TODO implement me
            return 1
        elif wireless=$(ip link | grep -oiP 'wlp[a-z0-9]+')
        then
            wifimenu
        fi

    fi

    return 0
}

default_keymap="de-latin1"
read -p "Keymap  [$default_keymap]: " keymap
keyboard_layout="${keymap:=$default_keymap}"

loadkeys "$keymap"


block_devices=($(lsblk -lpo NAME | grep -P '^/.*[^\d]$'))
if [[ ${#block_devices[@]} -eq 0 ]]
then
    echo "No block devices found!"
    exit 1
fi

if [[ ${#block_devices[@]} -gt 1 ]]
then
    echo "Devices: ${block_devices[@]}"
    read -p "Select disk: " disk
else
    disk="${block_devices[0]}"
fi

if ! file -s $disk
then
    echo "Disk not found!"
    exit 1
fi


boot_size=512
swap_size=$((1024 * 4))
swap_end=$(($boot_size + $swap_size))

parted="parted --script --align=opt $disk"
$parted mktable gpt
$parted mkpart primary ext4 "0%" "${boot_size}MiB"
$parted name 1 boot
$parted set 1 boot on
$parted mkpart primary 'linux-swap(new)' "${boot_size}MiB" "${swap_end}MiB"
$parted name 2 swap
$parted mkpart primary btrfs "${swap_end}MiB" "100%"
$parted name 3 root

boot="${disk}1"
swap="${disk}2"
root="${disk}3"

pacman --noconfirm -Syu
install=(pacman --noconfirm --needed -S)

$install btrfs-progs

mkfs.fat -F 32 -n BOOT $boot
mkswap         -L swap $swap
mkfs.btrfs     -L root $root

root_mp="/mnt"
boot_mp="${root_mb}/boot"

mount "$root" "$root_mp"
mkdir "$boot_mp"
mount "$boot" "$boot_mp"
swapon "$swap"

$install reflector
reflector --country Germany \
          --protocol https \
          --fastest 5 \
          --latest 30 \
          --sort score \
          --save /etc/pacman.d/mirrorlist
pacstrap "$root_mp" base grub
genfstab -pL "$root_mp" >> "${root_mp}/etc/fstab"

if stat /sys/firmware/efi/efivars > /dev/null 2>&1
then
    echo "UEFI support detected, installing GRUB2 to the EFI partition"
    read -p "EFI boot name: " efi_name
    target=x86_64-efi
    grub-install --target="$target" \
                 --efi-directory="${boot_mp}/${target}" \
                 --bootloader-id="$efi_name" \
                 --recheck
else
    echo "Legacy boot detected, installing GRUB2 to the MBR"
    grub-install $disk
fi

wget --quiet \
     --include bootstrap \
     --mirror \
     --recursive \
     --no-parent \
     --reject "index.html*" \
     --no-host-directories \
     "-P${root_mp}/root" \
     https://arch.cubyte.org

echo "KEYMAP=$keymap" > "${root_mp}/etc/vconsole.conf"

echo arch-chroot "$root_mp" /bin/bash /root/bootstrap/setup.sh
exit 0

umount "$boot_mp"
umount "$root_mp"
swapoff "$swap"
