#!/bin/bash
#
# Firmware downloader & extractor for realme-bale / realme-rmx3852.
# Based on The FairPhone (Gen. 6) FW exctractor script (https://github.com/FairBlobs/FP6-firmware/blob/master/extract.sh).
set -e

cleanup() {
    set +e
    sudo umount "$mntpnt"

    adb shell rm -r "$tmpdira"

    sudo dmsetup remove /dev/mapper/dynpart-*
    sudo losetup -d "$loopdev"

    sudo rm -r tmp*
}
trap cleanup EXIT

### Clean up old FW ###
echo -e "Cleaning up old firmware..."
if ls adsp* > /dev/null 2>&1; then      # ADSP
    rm adsp* ; rm battmgr.jsn
fi

if ls ms* > /dev/null 2>&1; then        # Bluetooth
    rm ms*
fi

if ls cdsp* > /dev/null 2>&1; then      # CDSP
    rm cdsp*
fi

if ls gen71100* > /dev/null 2>&1; then  # GPU
    rm gen71100*
fi

if ls ipa* > /dev/null 2>&1; then       # IPA
    rm ipa_fws.*
fi

if ls vpu* > /dev/null 2>&1; then       # Iris
    rm vpu33_4v.mbn
fi

if ls modem* > /dev/null 2>&1; then     # MPSS
    rm -r modem*
fi

if ls wpss* > /dev/null 2>&1; then      # WPSS
    rm wpss*
fi

rm README.md
echo -e "Cleanup completed!"

export tmpdira="/sdcard/ext_temp"
tmpdir=$(mktemp -dp .)
mntpnt=$(mktemp -dp . --suffix=.mnt)

echo -e "Please conenct your device to the computer for firmware extraction..."
export BSLOT="$(adb wait-for-device shell su -c "getprop ro.boot.slot_suffix")"
echo -e "Device found! Current boot slot is '$BSLOT'."
sleep 2
echo -e "Starting extraction in 3 seconds... Do not disconnect / power off / reboot your device!"
sleep 3

### Pull partition images from device ###
adb shell mkdir -p /sdcard/ext_temp

adb shell su -c "dd if=/dev/block/by-name/bluetooth'$BSLOT' of='$tmpdira'/bluetooth.img" ; adb pull "$tmpdira"/bluetooth.img "$tmpdir"/bluetooth.img
adb shell su -c "dd if=/dev/block/by-name/modem'$BSLOT' of='$tmpdira'/modem.img" ; adb pull "$tmpdira"/modem.img "$tmpdir"/modem.img
adb shell su -c "dd if=/dev/block/by-name/super of='$tmpdira'/super.img" ; adb pull "$tmpdira"/super.img "$tmpdir"/super.img

### Firmware extraction ###
# Connectivity & *DSP / *PSS
sudo mount -o ro "$tmpdir"/modem.img "$mntpnt"
cp "$mntpnt"/image/adsp* .
cp "$mntpnt"/image/battmgr.jsn .
cp "$mntpnt"/image/cdsp* .
cp "$mntpnt"/image/ipa_fws.* .
cp -r "$mntpnt"/image/modem* .
cp "$mntpnt"/image/qca6750/wpss{.mdt,.b*} .
sudo umount "$mntpnt"

# Bluetooth
sudo mount -o ro "$tmpdir"/bluetooth.img "$mntpnt"
cp "$mntpnt"/image/msbtfw12.mbn .
cp "$mntpnt"/image/msnv12.bin .
sudo umount "$mntpnt"

# GPU & Iris
loopdev=$(sudo losetup --read-only --find --show "$tmpdir"/super.img)
sudo dmsetup create --concise "$(sudo parse-android-dynparts "$loopdev")"

sudo mount -o ro /dev/mapper/dynpart-vendor"$BSLOT" "$mntpnt"
cp "$mntpnt"/firmware/{gen71100_gmu.bin,gen71100_sqe.fw,gen71100_zap.mbn} .
cp "$mntpnt"/firmware/vpu33_4v.mbn .

### Regenerate readme ###
cat >> README.md << 'END'
### realme GT Neo6 (realme-bale / realme-rmx3852) firmware information:
<!-- This file was generated using extract_fw.sh. DO NOT EDIT! -->
- **Realme UI version:** RUIVER
- **ColorOS base version:** COSVER
- **Android version:** AVER
- **Security patch:** OSPL
- **Extracted contents:**
  - Adreno GPU firmware
  - Audio Digital Signal Processor firmware
  - Bluetooth firmware
  - Compute Digital Signal Processor firmware
  - Internet Packet Accelerator firmware
  - Modem Processor Subsystem firmware
  - Iris video de/encoder firmware
  - WLAN Processor Subsystem firmware
END

export RUIVER=$(adb shell su -c "getprop ro.build.display.id" | sed 's/.*_/V/g')
export COSVER=$(adb shell su -c "getprop ro.build.version.oplusrom")
export AVER=$(adb shell su -c "getprop ro.build.version.release")
export OSPL=$(adb shell su -c "getprop ro.build.version.security_patch" | sed 's/-/./g')

if [ -z "$RUIVER" ]; then
    sed -i s/RUIVER/Unknown/g README.md
else
    sed -i s/RUIVER/"$RUIVER"/g README.md
fi

if [ -z "$COSVER" ]; then
    sed -i s/COSVER/Unknown/g README.md
else
    sed -i s/COSVER/"$COSVER"/g README.md
fi

if [ -z "$AVER" ]; then
    sed -i s/AVER/Unknown/g README.md
else
    sed -i s/AVER/"$AVER"/g README.md
fi

if [ -z "$OSPL" ]; then
    sed -i s/OSPL/Unknown/g README.md
else
    sed -i s/OSPL/"$OSPL"/g README.md
fi
