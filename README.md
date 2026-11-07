# ffmpeg-patched

[![verify against upstream](https://github.com/hot-YUser/ffmpeg-patched/actions/workflows/verify.yml/badge.svg)](https://github.com/hot-YUser/ffmpeg-patched/actions/workflows/verify.yml)

A fix for FFmpeg's OpenEXR PIZ decoder that upstream has not merged yet, kept
applying cleanly to the latest master and checked every day.

This repository holds **no FFmpeg source**. It holds the patches, the test
assets, and the automation that replays them onto a fresh upstream clone.

## The bug

OpenEXR images whose PIZ Huffman table needs codes longer than 14 bits come
back with 32-line horizontal black bands. Only a log line is emitted; decoding
"succeeds". Upstream issue
[#24027](https://code.ffmpeg.org/FFmpeg/FFmpeg/issues/24027).

The files themselves are fine, so nothing has to be re-exported.

## Get a build

Windows x64, static, no DLLs needed: the **Actions → windows build** artifacts,
or the Releases page when one has been published.

## Check any build yourself

```bash
tests/verify.sh /path/to/ffmpeg
```

Four checks, ~2 seconds, no network. Each compares real decoder output against
a hash produced by a verified build, cross-checked against the OpenEXR
reference library 3.4.13. An unpatched FFmpeg fails them.

## How the automation works

Every day the workflow clones upstream master fresh and does this:

1. Build **pristine** upstream and run `tests/verify.sh` on it.
2. Apply the patches with `git am`, rebuild, verify again.
3. Run `fate-exr` as a regression net.

| What happened | What it means |
|---|---|
| Pristine upstream **passes** | Upstream fixed it. This repo is done — retire the patches. |
| `git am` fails | Upstream moved the code. Needs a human rebase. |
| Applies, but verify **fails** | **Do not ship.** Upstream likely fixed the same bug another way, so the patch now double-corrects. |
| Everything passes | Normal. The upstream commit is recorded in `state/`. |

The third row is the reason the gate is behaviour and not "did the patch
apply": upstream can fix the same bug in code the patch does not touch. That
change conflicts with nothing, so a merge-conflict alarm stays silent while the
output goes wrong.

Rebuilding from patches onto a fresh clone, rather than maintaining a merged
fork, is what makes each day independent. There is no accumulated merge state
to go quietly wrong, and `git diff upstream/master..HEAD` is always exactly the
patches in `patches/`.

## Build it yourself

```bash
git clone --depth 1 https://code.ffmpeg.org/FFmpeg/FFmpeg.git src
git -C src am ../patches/*.patch
cd src && ./configure --disable-doc && make -j$(nproc)
```

`.github/workflows/windows-build.yml` records the full static Windows recipe.

## When this ends

The moment upstream merges a fix, the daily run says so and the patches should
be deleted. Nothing here is meant to be permanent.

## License and provenance

The patches are derivative works of FFmpeg and carry its license: LGPL v2.1+,
or GPL for the parts that require it.

Published binaries are configured with `--enable-gpl --enable-version3`, so
they are GPL v3. The complete corresponding source is the upstream commit
recorded in `BUILD-INFO.txt` plus the `patches/` directory shipped with them.

The patches were authored with AI assistance and reviewed by a human before
submission; the upstream issue says so explicitly.
