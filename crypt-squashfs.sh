#!/bin/sh

# https://martin.elwin.com/blog/2008/05/backups-with-squashfs-and-luks/

set -e

SQUASHFS_IMG="$1"
LUKS_IMG="$2"
CRYPTNAME=mkcrypt-$RANDOM
CRYPTDEV="/dev/mapper/$CRYPTNAME"
OVERHEAD=32768

BLOCKCOUNT=$(du --block-size=512 "$SQUASHFS_IMG" | cut -f1)

dd if=/dev/zero of="$LUKS_IMG" bs=512 count=1 seek=$(($BLOCKCOUNT + $OVERHEAD))
LOOPDEV=$(losetup -f)
losetup "$LOOPDEV" "$LUKS_IMG"
cryptsetup luksFormat "$LOOPDEV"
cryptsetup open "$LOOPDEV" "$CRYPTNAME"

if test $(blockdev --getsize "$CRYPTDEV") -lt $BLOCKCOUNT; then
	DELTA=$(( $BLOCKCOUNT - $(blockdev --getsize "$CRYPTDEV") ))
	echo "Cannot fit image into available space! Increase overhead by $DELTA"

	cryptsetup close "$CRYPTNAME"
	losetup -d "$LOOPDEV"
	rm "$LUKS_IMG"
	exit 1
fi
dd if="$SQUASHFS_IMG" of="$CRYPTDEV" status=progress

cryptsetup luksClose "$CRYPTNAME"
losetup -d "$LOOPDEV"

echo "Complete! You may delete $SQUASHFS_IMG after testing the output."
