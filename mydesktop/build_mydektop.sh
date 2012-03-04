#!/bin/bash

set -e -u

iso_name=mydesktop
iso_label="ARCH_$(date +%Y%m)"
iso_version=$(date +%Y.%m.%d)
install_dir=arch
arch=$(uname -m)
work_dir=work
out_dir=out
verbose="y"

script_path=$(readlink -f ${0%/*})

# Base installation (root-image)
make_basefs() {
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" -p "base" create
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" -p "syslinux mkinitcpio-nfs-utils nbd curl" create
}


# Copy mkinitcpio archiso hooks (root-image)
make_setup_mkinitcpio() {
   if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
       local _hook
       for _hook in archiso archiso_shutdown archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_loop_mnt; do
           cp /lib/initcpio/hooks/${_hook} ${work_dir}/root-image/lib/initcpio/hooks
           cp /lib/initcpio/install/${_hook} ${work_dir}/root-image/lib/initcpio/install
       done
       cp /lib/initcpio/install/archiso_kms ${work_dir}/root-image/lib/initcpio/install
       cp /lib/initcpio/archiso_shutdown ${work_dir}/root-image/lib/initcpio
       cp /lib/initcpio/archiso_pxe_nbd ${work_dir}/root-image/lib/initcpio
       cp ${script_path}/mkinitcpio.conf ${work_dir}/root-image/etc/mkinitcpio-archiso.conf
       : > ${work_dir}/build.${FUNCNAME}
   fi
}


# Prepare ${install_dir}/boot/
make_boot() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
        local _src=${work_dir}/root-image
        local _dst_boot=${work_dir}/iso/${install_dir}/boot
        mkdir -p ${_dst_boot}/${arch}
        mkarchroot -n -r "mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img" ${_src}
        mv ${_src}/boot/archiso.img ${_dst_boot}/${arch}/archiso.img
        mv ${_src}/boot/vmlinuz-linux ${_dst_boot}/${arch}/vmlinuz
        #cp ${_src}/boot/memtest86+/memtest.bin ${_dst_boot}/memtest
        #cp ${_src}/usr/share/licenses/common/GPL2/license.txt ${_dst_boot}/memtest.COPYING
        : > ${work_dir}/build.${FUNCNAME}
    fi
}


# Prepare /${install_dir}/boot/syslinux
make_syslinux() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
        mkdir -p ${work_dir}/iso/${install_dir}/boot/syslinux
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
            s|%INSTALL_DIR%|${install_dir}|g;
            s|%ARCH%|${arch}|g" ${script_path}/syslinux/syslinux.cfg > ${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg
        cp ${script_path}/syslinux/splash.png ${work_dir}/iso/${install_dir}/boot/syslinux/
        cp ${work_dir}/root-image/usr/lib/syslinux/*.c32 ${work_dir}/iso/${install_dir}/boot/syslinux/
        cp ${work_dir}/root-image/usr/lib/syslinux/*.com ${work_dir}/iso/${install_dir}/boot/syslinux/
        cp ${work_dir}/root-image/usr/lib/syslinux/*.0 ${work_dir}/iso/${install_dir}/boot/syslinux/
        cp ${work_dir}/root-image/usr/lib/syslinux/memdisk ${work_dir}/iso/${install_dir}/boot/syslinux/

        : > ${work_dir}/build.${FUNCNAME}
    fi
}

# Prepare /isolinux
make_isolinux() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
        mkdir -p ${work_dir}/iso/isolinux
        sed "s|%INSTALL_DIR%|${install_dir}|g" ${script_path}/isolinux/isolinux.cfg > ${work_dir}/iso/isolinux/isolinux.cfg
        cp ${work_dir}/root-image/usr/lib/syslinux/isolinux.bin ${work_dir}/iso/isolinux/
        cp ${work_dir}/root-image/usr/lib/syslinux/isohdpfx.bin ${work_dir}/iso/isolinux/

        : > ${work_dir}/build.${FUNCNAME}
    fi
}

# Process aitab
make_aitab() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
        sed "s|%ARCH%|${arch}|g" ${script_path}/aitab > ${work_dir}/iso/${install_dir}/aitab

        : > ${work_dir}/build.${FUNCNAME}
    fi
}

# Build all filesystem images specified in aitab (.fs .fs.sfs .sfs)
make_prepare() {
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" prepare
}

# Build ISO
make_iso() {
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" checksum
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" -L "${iso_label}" -o "${out_dir}" iso "${iso_name}-${iso_version}-${arch}.iso"
}

# Additional packages (root-image)
make_packages() {
    mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" -p "$(grep -v ^# ${script_path}/packages.${arch})" create
}

# Customize installation (root-image)
make_customize_root_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
        cp -af root-image ${work_dir}

        chroot ${work_dir}/root-image /usr/sbin/locale-gen
        chroot ${work_dir}/root-image /usr/sbin/useradd -m -p "" -g users -G "video,audio,disk,optical,wheel,storage,uucp" archme
        chroot ${work_dir}/root-image /bin/chown -R archme.users /home/archme

        chroot ${work_dir}/root-image /bin/bash -c "echo 'root:root' | chpasswd"
        chroot ${work_dir}/root-image /bin/bash -c "echo 'archme:archme' | chpasswd"
        chmod 600 ${work_dir}/root-image/etc/shadow

        chmod 750 ${work_dir}/root-image/etc/sudoers.d
        chmod 440 ${work_dir}/root-image/etc/sudoers.d/archme
        chmod 750 ${work_dir}/root-image/root

        : > ${work_dir}/build.${FUNCNAME}
    fi
}

# Setup local repository (root-image)
make_local_repo() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
        mkdir -p ${work_dir}/root-image/repo/local/${arch}
        mkarchroot -n -r "/usr/bin/pacman -Syw --noconfirm --cachedir /repo/local/${arch}/ xf86-video-intel xf86-video-ati xf86-video-vesa nvidia virtualbox-archlinux-modules virtualbox-archlinux-additions" ${work_dir}/root-image
        repo-add ${work_dir}/root-image/repo/local/${arch}/local.db.tar.gz ${work_dir}/root-image/repo/local/${arch}/*.pkg.tar.xz

        : > ${work_dir}/build.${FUNCNAME}
    fi
}

# We need synced pacman on bootup
make_resync() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
        chroot ${work_dir}/root-image /usr/bin/pacman -Sy

        : > ${work_dir}/build.${FUNCNAME}
    fi
}

if [[ $verbose == "y" ]]; then
    verbose="-v"
else
    verbose=""
fi

make_basefs
make_packages
make_customize_root_image
#make_local_repo
make_setup_mkinitcpio
make_boot
make_syslinux
make_isolinux
make_aitab
make_prepare
make_iso
