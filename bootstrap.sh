#!/bin/bash

verify_network() {
    wget -q --spider http://google.com
    return $?
}

setup_network() {
    if ! verify_network
    then
        if ethernet=$(ip link | grep -oiP 'enp[a-z0-9]+')
        then
            #TODO implement me
            return 1
        elif wireless=$(ip link | grep -oiP 'wlp[a-z0-9]+')
        then
            wifimenu
        fi

        if ! verify_network
        then
            return 1
        fi
    fi

    return 0
}

show_disks() {
    lsblk -lp | grep -vP '(part|rom|loop)'
}

test_disk() {
    if ! file -s $1 > /dev/null 2>&1
    then
        echo "Device does not seem to exist!"
        return 1
    fi

    return 0
}

default_keymap="de-latin1"
read -p "Keymap  [$default_keymap]: " keymap
keyboard_layout="${keymap:=$default_keymap}"

loadkeys "$keyboard_layout"

if setup_network
then
    echo "Network connection available!"
else
    echo "No network connection possible, ensure a connection before running this script!"
    exit 1
fi

stat /sys/firmware/efi/efivars > /dev/null 2>&1
efi_mode=$?

root_mp="/mnt"
boot_mp="${root_mp}/boot"

read -p "Automatic disk setup (this will wipe the selected disk)? [y|n]" -n 1 -r
echo
if [[ $REPLY =~ ^[jJyY]$ ]]
then
    block_devices=($(lsblk -lpo NAME | grep -P '^/.*[^\d]$'))
    if [[ ${#block_devices[@]} -eq 0 ]]
    then
        echo "No block devices found!"
        exit 1
    fi

    default_block_device=${block_devices[0]}
    show_disks
    read -p "Disk [$default_block_device]: " block_device
    disk="${block_device:=$default_block_device}"

    if ! test_disk $disk
    then
        exit 1
    fi

        read -p "Press [Enter] to wipe $disk and initialize it with new partitions"

    memory_size=$(free -m | grep -oP '\d+' | head -n 1)

    parted="parted --script --align=opt $disk"
    $parted mktable gpt
    if [[ $efi_mode -eq 0 ]]
    then
        boot_size=1024
        $parted mkpart primary fat32 "0%" "${boot_size}MiB"
        $parted name 1 boot
        $parted set 1 boot on
    else
        boot_size=1
        $parted mkpart primary fat32 "0%" "${boot_size}MiB"
        $parted set 1 bios_grub on
    fi
    swap_size=$memory_size
    swap_end=$(($boot_size + $swap_size))
    $parted mkpart primary 'linux-swap(new)' "${boot_size}MiB" "${swap_end}MiB"
    $parted name 2 swap
    $parted mkpart primary btrfs "${swap_end}MiB" "100%"
    $parted name 3 root

    boot="${disk}1"
    swap="${disk}2"
    root="${disk}3"

    pacman --noconfirm -Sy
    install="pacman --noconfirm --needed -S"

    mkswap -L swap $swap
    swapon "$swap"

    $install btrfs-progs
    mkfs.btrfs  -f -L root $root
    mount "$root" "$root_mp"

    if [[ $efi_mode -eq 0 ]]
    then
        mkfs.fat -F 32 -n BOOT $boot
        mkdir "$boot_mp"
        mount "$boot" "$boot_mp"
    fi
else
    echo -e "\n\n\n"
    echo "####### Manual mode..."
    echo "The script assumes all partitions have been configured properly."
    echo "The root partition must be mounted on /mnt and other partitions below ${root_mp}."
    echo "The Swap partition must be enabled using the swapon command."
    echo
    read -p "Press [Enter] to continue"
fi

if ! mount | grep "on ${root_mp}"
then
    echo "No disk is mounted on ${root_mp}, exiting..."
    exit 1
fi

mirrorlist="/etc/pacman.d/mirrorlist"
$install reflector
reflector --country Germany \
          --protocol https \
          --fastest 5 \
          --latest 30 \
          --sort score \
          --save "$mirrorlist"
pacstrap "$root_mp" base grub
genfstab -pL "$root_mp" >> "${root_mp}/etc/fstab"

if [[ $efi_mode -eq 0 ]]
then
    echo "UEFI support detected, installing GRUB2 to the EFI partition"
    read -p "EFI boot name: " efi_name
    target=x86_64-efi

    arch-chroot "$root_mp" /usr/bin/grub-install \
                 --target="$target" \
                 --efi-directory="${boot_mp}" \
                 --bootloader-id="$efi_name" \
                 --recheck
else
    echo "Legacy boot detected, installing GRUB2 to the MBR"
    while [[ -z "$disk" ]] && ! test_disk $disk
    do
        show_disks
        read -p "Disk to install GRUB to: " disk
    done
    arch-chroot "$root_mp" /usr/bin/grub-install $disk
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

echo "KEYMAP=$keyboard_layout" > "${root_mp}/etc/vconsole.conf"
cp "$mirrorlist" "${root_mp}${mirrorlist}"

arch-chroot "$root_mp" /bin/bash /root/bootstrap/setup.sh

umount "$boot_mp"
umount "$root_mp"
swapoff "$swap"
