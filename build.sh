#!/bin/sh

set -e

TOPDIR=$(pwd)
PATCHESDIR=$TOPDIR/patches
TMPDIR=$TOPDIR/tmp
SRCDIR=$TMPDIR/src
NR_JOBS=1

usage()
{
	cat << EOF
Usage: build.sh [OPTIONS] TARGET
Toolchain build script.

  -j            Number of parallel jobs

TARGET may be one of arm or tic6x.
EOF
	exit 1
}

apply_patches()
{
	find $PATCHESDIR/$1 -type f | sort -n | xargs git am
}

build_binutils()
{
	mkdir -p $SRCDIR
	cd $SRCDIR
	git clone --branch=binutils-2_42-branch --shallow-since=2024 https://sourceware.org/git/binutils-gdb.git binutils
	cd binutils
	git checkout -b local 758a2290dbdf0d6d6c148c6cf25b2bcfd7a5b84f
	apply_patches binutils

	mkdir -p $BUILDDIR/binutils
	cd $BUILDDIR/binutils
	$SRCDIR/binutils/configure \
		--target=$TARGET \
		--prefix=$HOSTDIR \
		--without-x \
		--without-tcl \
		--without-tk \
		--without-gdb \
		--enable-silent-rules \
		--enable-initfini-array \
		--enable-lto \
		--enable-plugins \
		--disable-nls \
		--disable-gdb \
		--disable-gdbtk
	make -j$NR_JOBS
	make install
}

build_gcc()
{
	mkdir -p $SRCDIR
	cd $SRCDIR
	git clone --branch=releases/gcc-13 --shallow-since=2024 https://gcc.gnu.org/git/gcc.git gcc
	cd gcc
	git checkout -b local aa20174c388e5b106b913055ddb41898d30881cd
	apply_patches gcc

	mkdir -p $BUILDDIR/gcc
	cd $BUILDDIR/gcc
	$SRCDIR/gcc/configure \
		--target=$TARGET \
		--prefix=$HOSTDIR \
		--with-newlib \
		--without-headers \
		--enable-silent-rules \
		--enable-checking=release \
		--enable-languages=c,c++ \
		--enable-tls \
		--enable-lto \
		--enable-static \
		--enable-libstdcxx \
		--enable-cxx-flags="$TARGET_CFLAGS" \
		--disable-shared \
		--disable-nls \
		--disable-libssp \
		$TARGET_GCC_CONFIGURE_OPTIONS
	make -j$NR_JOBS all-gcc all-target-libgcc
	make install-gcc install-target-libgcc
}

build_gcc_libstdcxx()
{
	cd $BUILDDIR/gcc
	make -j$NR_JOBS all-target-libstdc++-v3
	make install-target-libstdc++-v3
}

build_newlib()
{
	mkdir -p $SRCDIR
	cd $SRCDIR
	git clone --shallow-since=2023 https://sourceware.org/git/newlib-cygwin.git newlib
	cd newlib
	git checkout -b local newlib-4.4.0
	apply_patches newlib

	mkdir -p $BUILDDIR/newlib
	cd $BUILDDIR/newlib
	PATH=$HOSTDIR/bin:$PATH $SRCDIR/newlib/configure \
		--target=$TARGET \
		--prefix=/ \
		--enable-silent-rules \
		--enable-newlib-io-pos-args \
		--enable-newlib-io-c99-formats \
		--enable-newlib-retargetable-locking \
		--enable-newlib-reent-check-verify \
		--enable-newlib-io-long-long \
		--enable-lite-exit \
		--disable-newlib-wide-orient \
		--disable-newlib-supplied-syscalls \
		--disable-libssp
	PATH=$HOSTDIR/bin:$PATH make -j$NR_JOBS CFLAGS_FOR_TARGET="$TARGET_CFLAGS"
	PATH=$HOSTDIR/bin:$PATH make DESTDIR=$HOSTDIR install
}

while getopts ":j:" o; do
	case "$o" in
	j)
		NR_JOBS=$OPTARG
		;;
	*)
		usage
		;;
	esac
done

shift $((OPTIND - 1))

if [ -z "$1" ]; then
	usage
elif [ "$1" = "arm" ]; then
	TARGET=arm-none-eabi
	TARGET_CFLAGS="-O3 -g"
	TARGET_GCC_CONFIGURE_OPTIONS="--with-multilib-list=aprofile,rmprofile"
elif [ "$1" = "tic6x" ]; then
	TARGET=tic6x-none-elf
	TARGET_CFLAGS="-O3 -g -march=c674x -mno-dsbt -msdata=none"
	TARGET_GCC_CONFIGURE_OPTIONS=
else
	echo "target unknown"
	exit 1
fi

TOOLCHAIN=sbg-gcc-$TARGET-$(date "+%Y%m%d")
BUILDDIR=$TMPDIR/$TARGET/build
HOSTDIR=$TMPDIR/$TARGET/$TOOLCHAIN

rm -rf $TMPDIR
build_binutils
build_gcc
build_newlib
build_gcc_libstdcxx

cd $HOSTDIR/..
tar cJf $TOOLCHAIN.tar.xz $TOOLCHAIN
md5sum $TOOLCHAIN.tar.xz > $TOOLCHAIN.tar.xz.md5
