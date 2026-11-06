#!/usr/bin/env bash
# Build only the missing media modules; never replaces the PS5 kernel.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KVER=$(uname -r)
BASE=${KVER%%[-+]*}
HEADERS=/lib/modules/$KVER/build
[[ $BASE =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Unsupported kernel version'; exit 1; }
[[ -r /boot/config-$KVER && -r $HEADERS/Module.symvers ]] || { echo 'Matching kernel config and headers are required.'; exit 1; }
for tool in curl tar make gcc flex bison bc python3; do
    command -v "$tool" >/dev/null || { echo "Missing build tool: $tool"; exit 1; }
done
# gendwarfksyms needs elfutils development headers for symbol versioning.
# Keep the running kernel's versioning configuration enabled.
if grep -q '^CONFIG_GENDWARFKSYMS=y$' "/boot/config-$KVER"; then
    if ! printf '#include <dwarf.h>\n#include <elfutils/libdw.h>\n#include <elfutils/libdwfl.h>\n' | gcc -E -x c - >/dev/null 2>&1; then
        echo 'Missing elfutils development headers (dwarf.h/libdw.h).'
        echo 'Install: sudo apt install libdw-dev'
        exit 1
    fi
fi
mkdir -p "$ROOT/src" "$ROOT/logs" "$ROOT/dist"
exec > >(tee "$ROOT/logs/build.log") 2>&1
SRC=$ROOT/src/linux-$BASE
if [[ ! -f $SRC/Makefile ]]; then
    ARCHIVE=$ROOT/src/linux-$BASE.tar.xz
    URL=https://cdn.kernel.org/pub/linux/kernel/v${BASE%%.*}.x
    curl --fail --location --retry 2 -o "$ARCHIVE.part" "$URL/linux-$BASE.tar.xz"
    curl --fail --location --retry 2 -o "$ROOT/src/sha256sums.asc" "$URL/sha256sums.asc"
    python3 - "$ROOT/src/sha256sums.asc" "$ARCHIVE.part" "linux-$BASE.tar.xz" <<'PY'
import hashlib, pathlib, sys
lines = pathlib.Path(sys.argv[1]).read_text().splitlines()
expected = [line.split()[0] for line in lines if len(line.split()) == 2 and line.split()[1].lstrip('*') == sys.argv[3]]
if len(expected) != 1:
    raise SystemExit('Cannot find unique official archive checksum')
h = hashlib.sha256()
with open(sys.argv[2], 'rb') as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b''):
        h.update(chunk)
if h.hexdigest() != expected[0]:
    raise SystemExit('Kernel archive checksum mismatch')
PY
    mv "$ARCHIVE.part" "$ARCHIVE"
    tar -xJf "$ARCHIVE" -C "$ROOT/src"
fi
cp "/boot/config-$KVER" "$SRC/.config"
C=("$SRC/scripts/config" --file "$SRC/.config")
"${C[@]}" --module MEDIA_SUPPORT --enable MEDIA_SUPPORT_FILTER \
    --enable MEDIA_CAMERA_SUPPORT --enable MEDIA_USB_SUPPORT \
    --module VIDEO_DEV --module USB_VIDEO_CLASS \
    --disable MEDIA_CONTROLLER --disable MEDIA_TEST_SUPPORT \
    --disable MEDIA_ANALOG_TV_SUPPORT --disable MEDIA_DIGITAL_TV_SUPPORT \
    --disable MEDIA_RADIO_SUPPORT --disable MEDIA_SDR_SUPPORT \
    --disable LOCALVERSION_AUTO
CC=${CC:-gcc}
if command -v gcc-14 >/dev/null && [[ $CC == gcc ]]; then CC=gcc-14; fi
JOBS=${JOBS:-4}
make -C "$SRC" CC="$CC" olddefconfig
[[ $(make -s -C "$SRC" CC="$CC" kernelrelease) == "$KVER" ]] || {
    echo 'Source kernel release differs from running kernel; refusing build.'; exit 1;
}
make -C "$SRC" CC="$CC" -j"$JOBS" modules_prepare
# Preserve CRCs for symbols exported by the actual running PS5 kernel.
cp "$HEADERS/Module.symvers" "$SRC/Module.symvers"
# CEC is already built into the PS5 kernel. Enabling modular MEDIA_SUPPORT
# can turn CEC_CORE into a module during olddefconfig; exclude that subtree.
make -C "$SRC" CC="$CC" -j"$JOBS" M=drivers/media CONFIG_CEC_CORE= modules
find "$ROOT/dist" -maxdepth 1 -type f -name '*.ko' -delete
# Stage only this build's module list, excluding stale products of prior builds.
while IFS= read -r module; do
    [[ $module != /* && $module != *..* && $module == *.o ]] || exit 1
    cp "$SRC/drivers/media/${module%.o}.ko" "$ROOT/dist/"
done < "$SRC/drivers/media/modules.order"
cp "$HEADERS/Module.symvers" "$ROOT/dist/kernel.symvers"
cp "$SRC/drivers/media/Module.symvers" "$ROOT/dist/media.symvers"
printf '%s\n' "$KVER" > "$ROOT/dist/kernel-release"
python3 "$ROOT/verify.py"
echo "Build verified. Install from your host terminal: sudo $ROOT/install.sh"
