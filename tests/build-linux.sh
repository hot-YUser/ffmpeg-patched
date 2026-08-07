#!/usr/bin/env bash
#
#   usage: tests/build-linux.sh <srcdir>
#
# A deliberately small, fully deterministic build: no external libraries, so
# the result depends only on the upstream commit and the patches.  ccache makes
# the second build of the same tree (the one with the patches applied) cost
# little more than recompiling the two touched files and relinking.
#
# zlib is enabled explicitly because --disable-autodetect would otherwise drop
# it, and most of the existing fate-exr tests decode ZIP compressed files.

set -eu

SRC=${1:?usage: build-linux.sh <srcdir>}
cd "$SRC"

if [ ! -f ffbuild/config.mak ]; then
    ./configure \
        --disable-doc \
        --disable-network \
        --disable-autodetect \
        --enable-zlib \
        --cc='ccache gcc' \
        --cxx='ccache g++' > configure.log 2>&1 || { tail -40 configure.log; exit 1; }
fi

make -j"$(nproc)" > build.log 2>&1 || {
    grep -iE 'error|Error [0-9]' build.log | head -30
    exit 1
}

./ffmpeg -version | head -1
