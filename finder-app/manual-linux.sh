#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64

# for some reason, debian binutils-aarch64-linux-gnu is completely different from docker aarch64 installation
if [ "$HOSTNAME" = "fdebian" ]; then
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_SYS_ROOT=/usr/aarch64-linux-gnu/
    CROSS_COMPILE_LIB=lib
else
    CROSS_COMPILE=aarch64-none-linux-gnu-
    CROSS_COMPILE_SYS_ROOT=$(${CROSS_COMPILE}gcc --print-sysroot)
    CROSS_COMPILE_LIB=lib64
fi

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$(realpath $1)
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}
    patch -p1 < "${FINDER_APP_DIR}/yylloc.patch"

    # TODO: Add your kernel build steps here
    ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make mrproper
    ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make defconfig
    ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make -j4 all
    ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make -j4 dtbs
fi

# echo "Adding the Image in outdir"
cp "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" "${OUTDIR}/Image"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr usr/bin usr/lib usr/sbin var var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make defconfig
else
    cd busybox
fi

# TODO: Make and install busybox
ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make -j4
ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make install CONFIG_PREFIX="${OUTDIR}/rootfs"

echo "Library dependencies"
cd "${OUTDIR}/rootfs"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
cp -L ${CROSS_COMPILE_SYS_ROOT}/lib/ld-linux-aarch64.so.1 lib/
cp -L ${CROSS_COMPILE_SYS_ROOT}/${CROSS_COMPILE_LIB}/libm.so.6 ${CROSS_COMPILE_LIB}/
cp -L ${CROSS_COMPILE_SYS_ROOT}/${CROSS_COMPILE_LIB}/libresolv.so.2 ${CROSS_COMPILE_LIB}/
cp -L ${CROSS_COMPILE_SYS_ROOT}/${CROSS_COMPILE_LIB}/libc.so.6 ${CROSS_COMPILE_LIB}/

# TODO: Make device nodes
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 666 dev/console c 5 1

# TODO: Clean and build the writer utility
cd "${FINDER_APP_DIR}"
ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make clean
ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} make

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp finder.sh "${OUTDIR}/rootfs/home/"
cp writer "${OUTDIR}/rootfs/home/"
mkdir -p "${OUTDIR}/rootfs/home/conf"
cp conf/* "${OUTDIR}/rootfs/home/conf/"
cp finder-test.sh "${OUTDIR}/rootfs/home/"
sed -i 's/..\/conf\//conf\//g' "${OUTDIR}/rootfs/home/finder-test.sh"
cp autorun-qemu.sh "${OUTDIR}/rootfs/home/"

# TODO: Chown the root directory
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
cd "${OUTDIR}/rootfs"
find .| cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f "${OUTDIR}/initramfs.cpio"
