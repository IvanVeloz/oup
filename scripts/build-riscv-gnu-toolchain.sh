#! /bin/sh

ENTRYPATH=$(pwd)
cd $(dirname $0)
SCRIPTPATH=$(pwd)
REPOROOT=${SCRIPTPATH}/..
TOOLCHAINPATH=${REPOROOT}/dependencies/riscv-gnu-toolchain

INSTALLPATH=${REPOROOT}/riscv

cd ${TOOLCHAINPATH}
./configure --prefix=${INSTALLPATH} --with-arch=rv32i --with-abi=ilp32
make