#!/usr/bin/bash

source backup.env

_log="gum log -t rfc822"

_info() {
	$_log -l info "$1"
}

_error() {
	$_log -l error "$1"
}

zip() {
	busybox find $TEMPFOLDER -type d -maxdepth 1 -mindepth 1 | busybox grep -Ev "RECYCLE.BIN|System Volume Information" | while read CHUNK; do
		C="$(basename $CHUNK)"
		gum spin --spinner dot --title "Zipping $C -> $C.zip" -- 7z a ${TEMPFOLDER}$C.zip -m0=lz4 -mx$LZ4MODE ${TEMPFOLDER}$C
		rm -rf ${TEMPFOLDER}$C
	done
	_info "Finished Zipping ${TEMPFOLDER}$1* -> ${TEMPFOLDER}$1*.zip"
}

encrypt() {
	busybox find $TEMPFOLDER -type f -maxdepth 1 -mindepth 1 | busybox grep -Ev "RECYCLE.BIN|System Volume Information" | while read CHUNK; do
		C="$(basename $CHUNK)"
		gum spin --spinner dot --title "Encrypting ${TEMPFOLDER}$C -> ${TEMPFOLDER}$C.gpg" -- gpg --compress-algo none --passphrase $PASSWORD -c --pinentry-mode loopback ${TEMPFOLDER}$C
		rm ${TEMPFOLDER}$C
	done
	_info "Finished Encrypting ${TEMPFOLDER}$1 -> ${TEMPFOLDER}$1.gpg"
}

chunk() {
	gum spin --spinner dot --title "Copying $1 -> ${TEMPFOLDER}$1" -- cp -r $1 ${TEMPFOLDER}$1
	gum spin --spinner dot --title "Splitting ${TEMPFOLDER}$1 into $CHUNKSIZE chunks" -- perl $DIRSPLIT -m -s $CHUNKSIZE -p ${TEMPFOLDER}$1_ ${TEMPFOLDER}$1
	gum spin --spinner dot --title "Removing ${TEMPFOLDER}$1" -- rm -rf ${TEMPFOLDER}$1
	_info "Finished Splitting $1 into $CHUNKSIZE chunks"
}

publish() {
	busybox find $TEMPFOLDER -type f -maxdepth 1 -mindepth 1 | busybox grep -Ev "RECYCLE.BIN|System Volume Information" | while read CHUNK; do
		C="$(basename $CHUNK)"
		gum spin --spinner dot --title "Moving ${TEMPFOLDER}$C -> $OUTFOLDER" -- mv ${TEMPFOLDER}$C $OUTFOLDER
	done
	_info "Finished Moving ${TEMPFOLDER}$1*.zip.gpg -> $OUTFOLDER"
}

backup() {
	chunk $1
	zip $1
	encrypt $1
	publish $1
}

check_space() {
	AVAIL=$(df $TEMPFOLDER | awk '{print $4}' | tail -n1)
	CURR=$(df . | awk '{print $3}' | tail -n1)
	if [ $(($AVAIL - ($CURR * 2))) -lt $SAFESIZE ]; then
		_error "The temporary drive $TEMPFOLDER does not have enough space for the backup to be safely executed ($(($AVAIL - ($CURR * 2))))"
		gum confirm "Keep Going?" || exit
	fi
}

check_space
busybox find . -type d -maxdepth 1 -mindepth 1 | busybox grep -Ev "RECYCLE.BIN|System Volume Information" | while read FOLDER; do
	backup $(basename $FOLDER)
done
