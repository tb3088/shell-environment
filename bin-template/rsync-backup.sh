#!/bin/bash

# Usage: $0 (remote)source (local)dest
#
# NOTE - this script ONLY works properly if DEST is local!
# if remote, the hardlinks, mkdir, and PREVIOUS won't work.
# 
# derived from http://www.sanitarium.net/golug/rsync_backups_2010.html

_token='.in-flight'

: ${SOURCE:=/export/home}
: ${DEST:=/backup/$SOURCE/`date --iso-8601=minutes`}
[ -d "$DEST" ] && { >&2 echo "ERROR directory exists ($DEST)"; exit 2; }

: ${PREVIOUS:=$( ls -pt `dirname "$DEST"` | grep '/$' | grep -v "$_token" | head -n 1 )}

_dest="${DEST%/}$_token"
mkdir -p "$_dest" || { >&2 echo "ERROR creating in-flight directory ($_dest)"; exit 1; }

rsync ${DEBUG:+ --verbose} ${VERBOSE:+ --progress --itemize-changes} \
  --archive --one-file-system --hard-links \
  --human-readable --inplace --numeric-ids --delete \
  --sparse \
  --delete-excluded --exclude-from="$SOURCE/.rsync-exclude" \
  ${PREVIOUS:+ --link-dest="$PREVIOUS"} \
  "${SOURCE%/}/" "$_dest" && mv -vn "$_dest" "${DEST%/}"

# --whole-file might be useful on a LAN
