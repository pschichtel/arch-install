#!/bin/bash

here="$(dirname "$(readlink -f "$0")")"

cp "${here}/files/etc/pacman.conf" /etc/pacman.conf

gpg -k
touch /root/.gnupg/dirmngr_ldapservers.conf
cubyte_key="DFF19658F3D621B5"
pacman-key --recv-keys "$cubyte_key"
pacman-key --lsign-key "$cubyte_key"
infinality_key="AE6866C7962DDE58"
pacman-key --recv-keys "$infinality_key"
pacman-key --lsign-key "$infinality_key"

pacman --noconfirm -Sy
pacman --noconfirm --needed -S $(grep -P '\S' "${here}/packages.txt" | grep -vP '^\s*#')

for service in $(cat "${here}/services.txt")
do
    systemctl enable $service
    #systemctl start $service
done

cp -R ${here}/files/* /

while [[ -z "$username" ]]
do
    read -p "Username: " username
done
useradd --create-home --home-dir "/home/${username}" $username
groupadd --system sudo
usermod -aG sudo ${username}

read -s -p "Password: " password
echo
if [[ ! -z "$password" ]]
then
    usermod --password "$password" $username
fi

default_hostname='arch'
read -p "Hostname [$default_hostname]: " hostname
echo "${hostname:=$default_hostname}" > /etc/hostname

default_timezone="Europe/Berlin"
read -p "Timezone [$default_timezone]: " timezone
ln -s "/usr/share/zoneinfo/${timezone:=$default_timezone}"

default_default_locale="de_DE.UTF-8"
read -p "Default Locale [$default_default_locale]: " default_timezone

default_language="$(grep -oP '^[^\.]+' <<< "${default_locale:=$default_default_locale}")"
read -p "Language [$default_language]: " language

locale_conf="/etc/locale.conf"
echo "LANG=${default_locale:=$default_default_locale}" > "$locale_conf"
echo 'LC_COLLATE=C'                                   >> "$locale_conf"
echo "LANGUAGE=${language:=$default_language}"        >> "$locale_conf"

locale_gen="/etc/locale.gen"
echo "en_US.UTF-8 UTF-8"        > "$locale_gen"
echo "${language}.UTF-8 UTF-8" >> "$locale_gen"
locale-gen

mkinitcpio -p linux
grub-mkconfig -o /boot/grub/grub.cfg

read -s -p "Root password []: "
echo

