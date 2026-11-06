# PS5 Ubuntu webcam fix

Build the missing Linux media, V4L2 and UVC modules for a PS5 Ubuntu kernel compiled with `CONFIG_MEDIA_SUPPORT` disabled.

Tested on a PS5 Slim, Ubuntu 26.04.1, kernel 7.2.3, with an AnkerWork C310 (`291a:3367`). The camera registered and the user confirmed working video. This is for a USB webcam attached to a PS5 running Linux; it is not a Sony HD Camera firmware loader.

## Build and install

Matching installed kernel headers and `/boot/config-$(uname -r)` are required.

```bash
sudo apt install build-essential flex bison bc libssl-dev libelf-dev libdw-dev curl xz-utils python3 kmod binutils
./build.sh
sudo ./install.sh
```

The build downloads matching kernel.org sources, checks the HTTPS checksum list, preserves the running kernel's BTF configuration, and builds the media subtree while excluding CEC already present in the kernel. It prefers GCC 14 when available. It does not replace your kernel image. GCC/compiler and PS5 patch differences can still affect runtime compatibility.

The installer checks kernel release, module structure size and imported symbol CRCs before installation. Use `sudo ./install.sh --replace` for an updated build: it requires the old modules to be unloaded and saves a backup. Never force-load a failed build.

The driver loads immediately; USB hotplug loads installed modules after reboot. Rebuild after kernel updates.

## Verify

```bash
sudo apt install v4l-utils
v4l2-ctl --list-devices
v4l2-ctl --device /dev/video0 --list-formats-ext
```

Select the webcam in your camera application and test capture.

## Remove

Close camera applications, then:

```bash
sudo modprobe -r uvcvideo
sudo rm -r -- /lib/modules/"$(uname -r)"/updates/ps5-webcam
sudo depmod -a
```

Reboot if other media modules remain loaded. Remove only the dedicated `ps5-webcam` directory.

## Scope and license

Validated on the setup above, not every PS5 kernel or webcam. Module ABI checks cannot prove all runtime compatibility. Build artifacts, local diagnostics and backups are excluded from Git. GPL-2.0-only; Linux sources are downloaded separately from https://cdn.kernel.org/pub/linux/kernel/v7.x/.

## Development and validation

Implementation and review were assisted by OpenAI Codex. Hardware results were checked interactively by the repository owner on one PS5 Slim. These are community workarounds with limited hardware coverage, not an official Sony or Ubuntu release. See `CREDITS.md` and `REVIEW.md` for provenance and review limits.
