#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $EUID == 0 ]] || { echo "Run: sudo $0"; exit 1; }
REPLACE=0
case ${1:-} in
    '') ;;
    --replace) REPLACE=1 ;;
    *) echo "Usage: sudo $0 [--replace]"; exit 1 ;;
esac
python3 "$ROOT/verify.py"
KVER=$(uname -r)
DEST=/lib/modules/$KVER/updates/ps5-webcam
if [[ -e $DEST ]]; then
    # Resume identical builds; explicitly replace older builds with a backup.
    shopt -s nullglob
    built=("$ROOT"/dist/*.ko)
    installed=("$DEST"/*.ko)
    [[ ${#built[@]} == ${#installed[@]} ]] || {
        echo 'Installed module set differs from this build; refusing replacement.'; exit 1;
    }
    for module in "${built[@]}"; do
        [[ -f $DEST/${module##*/} ]] || { echo 'Unexpected installed module names.'; exit 1; }
        if ! cmp -s "$module" "$DEST/${module##*/}"; then
            (( REPLACE )) || { echo "Updated build available. Run: sudo $0 --replace"; exit 1; }
        fi
    done
    if (( REPLACE )); then
        for module in "${built[@]}"; do
            name=${module##*/}; name=${name%.ko}; name=${name//-/_}
            [[ ! -e /sys/module/$name ]] || { echo "Close camera apps and unload $name before replacing modules."; exit 1; }
        done
        BACKUP=$ROOT/backups/$(date +%Y%m%d-%H%M%S)-$$
        install -d "$BACKUP"
        cp -a "$DEST"/. "$BACKUP/"
        install -m644 "${built[@]}" "$DEST/"
        echo "Replaced modules; previous build saved in $BACKUP"
    else
        echo 'Identical modules already installed; resuming driver loading.'
    fi
else
    install -d "$DEST"
    install -m644 "$ROOT"/dist/*.ko "$DEST/"
fi
depmod -a "$KVER"
if ! modprobe -v uvcvideo; then
    echo 'Driver loading failed. Recent kernel messages:'
    dmesg | tail -60
    exit 1
fi
shopt -s nullglob
devices=(/sys/class/video4linux/video*)
if (( ${#devices[@]} == 0 )); then
    echo 'Driver loaded but no camera registered. Check USB connection and sudo dmesg.'
    dmesg | tail -60
    exit 1
fi
printf 'Camera registered: %s\n' "${devices[@]}"
echo 'USB hotplug will load the driver automatically on future boots.'
