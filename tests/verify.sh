#!/usr/bin/env bash
#
# Behavioural gate for the OpenEXR PIZ fix this repo carries.
#
#   usage: tests/verify.sh <ffmpeg-binary> [workdir]
#   exit 0  every check passed  -> the binary decodes PIZ correctly
#   exit 1  at least one check failed
#
# This is deliberately the gate, instead of "did git am succeed".  A patch can
# apply with zero conflicts onto an upstream that has meanwhile fixed the same
# bug another way, and the result is a clean build that produces silently wrong
# pixels.  Only running the decoder catches that.
#
# The expected hashes below were produced by a patched build and cross checked
# against the OpenEXR reference library 3.4.13; see README.md.

set -u

FFMPEG=${1:?usage: verify.sh <ffmpeg-binary> [workdir]}
HERE=$(cd "$(dirname "$0")" && pwd)
ASSETS=$HERE/assets
WORK=${2:-$(mktemp -d)}
mkdir -p "$WORK"

# gbrpf32le of the two PIZ samples
PIZ448=81f5406d46dda0416f2e0d839353870bbae68060555afc1640580c5fbf7d0b07
PIZMIN=065f2b1322310f67a980f83f91854b48854e52873341e09b4766cb425aac11f8

pass=0
fail=0

# warning, not error: the EXR failure this checks for is announced at
# AV_LOG_WARNING, and decoding otherwise reports success with 0 decode errors.
ff () { "$FFMPEG" -nostdin -hide_banner -loglevel warning -y "$@"; }

check () {                                    # check <name> <want-sha> <file>
    local name=$1 want=$2 file=$3 got
    if [ ! -s "$file" ]; then
        printf '  FAIL  %-24s no output produced\n' "$name"
        fail=$((fail + 1))
        return
    fi
    got=$(sha256sum "$file" | cut -d' ' -f1)
    if [ "$got" = "$want" ]; then
        printf '  ok    %-24s %s\n' "$name" "${got:0:16}"
        pass=$((pass + 1))
    else
        printf '  FAIL  %-24s want %s\n' "$name" "${want:0:16}"
        printf '        %-24s got  %s\n' '' "${got:0:16}"
        fail=$((fail + 1))
    fi
}

check_clean_log () {                          # check_clean_log <name> <logfile>
    local name=$1 log=$2
    if grep -qi 'strange codes' "$log"; then
        printf '  FAIL  %-24s decoder logged "strange codes"\n' "$name"
        fail=$((fail + 1))
    else
        printf '  ok    %-24s no "strange codes"\n' "$name"
        pass=$((pass + 1))
    fi
}

echo "verifying: $FFMPEG"
"$FFMPEG" -version 2>/dev/null | head -1 | sed 's/^/  /'
echo

# A Huffman table needing codes longer than 14 bits overflows the int16_t VLC
# subtable index, and the whole 32 line scanline block comes back zero filled.
echo "OpenEXR PIZ (dense Huffman table)"
ff -i "$ASSETS/rgb_scanline_float_piz_dense_448x32.exr" -vf scale \
   -f rawvideo -pix_fmt gbrpf32le "$WORK/piz448.gbr" 2>"$WORK/piz448.log"
check exr-piz-dense "$PIZ448" "$WORK/piz448.gbr"
check_clean_log exr-piz-dense-log "$WORK/piz448.log"

ff -i "$ASSETS/min_piz.exr" -vf scale \
   -f rawvideo -pix_fmt gbrpf32le "$WORK/pizmin.gbr" 2>"$WORK/pizmin.log"
check exr-piz-min "$PIZMIN" "$WORK/pizmin.gbr"
check_clean_log exr-piz-min-log "$WORK/pizmin.log"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
