#!/bin/bash

LIB_CORE=/usr/lib/aif/core
LIB_USER=/usr/lib/aif/user
RUNTIME_DIR=/tmp/aif
LOG_DIR=/var/log/aif
LOGFILE=$LOG_DIR/aif.log

export LC_COLLATE=C
shopt -s extglob
#export var_UI_TYPE=dia
export var_UI_TYPE=cli

source ${LIB_CORE}/libs/lib-ui.sh || { echo "Error sourcing library ${LIB_CORE}/libs/lib-ui.sh" >&2 ; exit 2; }
ui_init
source ${LIB_CORE}/libs/lib-flowcontrol.sh || { echo "Error sourcing library ${LIB_CORE}/libs/lib-flowcontrol.sh" >&2 ; exit 2; }
source ${LIB_CORE}/libs/lib-misc.sh || { echo "Error sourcing library ${LIB_CORE}/libs/lib-misc.sh" >&2 ; exit 2; }
source ${LIB_CORE}/libs/lib-blockdevices-filesystems.sh || { echo "Error sourcing library ${LIB_CORE}/libs/lib-blockdevices-filesystems.sh" >&2 ; exit 2; }

DEVICES="$(finddisks '_ ')"

ask_option no "Choose Installation Target" "Where do you want to install ?" required ${DEVICES}
INSTDEV=${ANSWER_OPTION}

## partition Device
sfdisk -uM ${INSTDEV} << EOF
0,2048,,*
,1028
;
EOF

[ $? == 0 ] || die_error "Could not partition ${INSTDEV}"

## format device
mkfs.ext4 ${INSTDEV}1 || die_error "Could not format ${INSTDEV}1"
mkfs.ext4 ${INSTDEV}2 || die_error "Could not format ${INSTDEV}2"
mkfs.ext4 ${INSTDEV}3 || die_error "Could not format ${INSTDEV}2"

## label device
e2label ${INSTDEV}1 MYROOT || die_error "Could not label ${INSTDEV}1"
e2label ${INSTDEV}2 MYDATA || die_error "Could not label ${INSTDEV}2"
e2label ${INSTDEV}3 MYHOME || die_error "Could not label ${INSTDEV}3"

## mount and copy rootfs, homefs
mkdir -p /tmp/mnt/myroot
mkdir -p /tmp/mnt/myhome
mount ${INSTDEV}1 /tmp/mnt/myroot || die_error "Could not mount ${INSTDEV}1"
mount ${INSTDEV}3 /tmp/mnt/myhome || die_error "Could not mount ${INSTDEV}3"
cp -r /bootmnt/arch/ /tmp/mnt/myroot || die_error "Could not copy rootfs"
rsync -a /home/ /tmp/mnt/myhome || die_error "Could not copy homefs"

## install syslinux to rootfs
extlinux --install /tmp/mnt/myroot/arch/boot/syslinux/ || die_error "Could not install syslinux"

## write mbr to device
dd bs=440 conv=notrunc count=1 if=/usr/lib/syslinux/mbr.bin of=${INSTDEV} || die_error "Could not write mbr to ${INSTDEV}"

## reconfigure bootloader
#sed s/archisolabel=ARCH_....../archisolabel=MYROOT/g /bootmnt/arch/boot/syslinux/syslinux.cfg || die_error "Could not configure syslinux bootloader"

## unmount rootfs, homefs
umount /tmp/mnt/myroot || die_error "Could not umount ${INSTDEV}1"
umount /tmp/mnt/myhome || die_error "Could not umount ${INSTDEV}3"

#reboot

