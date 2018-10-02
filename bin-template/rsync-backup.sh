#!/bin/sh

: ${SOURCE:=/export/home}
: ${TARGET:=/backup/$SOURCE/`date --iso-8601=minutes`}
: ${PREVIOUS:=`ls -pt "${TARGET%/*}" | grep '/$' | head -n 1`}

mkdir -p "$TARGET"

rsync --archive --one-file-system --hard-links \
  ${DEBUG:+ --verbose} ${VERBOSE:+ --progress --itemize-changes} \
  --human-readable --inplace --numeric-ids --delete \
  --delete-excluded --exclude-from="$SOURCE/.rsync-exclude" \
  --link-dest="$PREVIOUS" \
  ${SOURCE}/ ${TARGET}/

# --sparse --whole-file when moving VMs
# http://www.sanitarium.net/golug/rsync_backups_2010.html
