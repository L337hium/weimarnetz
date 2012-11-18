#!/bin/sh

# todo:
# - stick to specific git-revision
# - autodownload .definitions

# arguments e.g.:
# "HARDWARE.Linksys WRT54G:GS:GL" standard kernel.addzram kcmdlinetweak patch:901-minstrel-try-all-rates.patch dataretention nopppoe b43minimal olsrsimple nohttps nonetperf
# "HARDWARE.TP-LINK TL-WR1043ND"  standard kernel.addzram kcmdlinetweak patch:901-minstrel-try-all-rates.patch dataretention

log()
{
	logger -s "$( date ): [$( pwd )]: $0: $1"
}

[ -z "$1" ] && {
	log "Usage: $0 <buildstring>"
	exit 1
}

[ "$( id -u )" = "0" ] && {
	log "please run as normal user"
	exit 1
}

changedir()
{
	[ -d "$1" ] || {
		log "creating dir $1"
		mkdir -p "$1"
	}

	log "going into $1"
	cd "$1"
}

clone()
{
	local repo="$1"
	local dir="$( basename "$repo" | cut -d'.' -f1 )"

	if [ -d "$dir" ]; then
		log "git-cloning of '$repo' already done, just pulling"
		changedir "$dir"
		git stash
		git checkout master
		git pull
		changedir ..
	else
		log "git-cloning from '$repo'"
		git clone "$repo"
	fi
}

mymake()	# fixme! how to ahve a quiet 'make defconfig'?
{
	log "[START] executing 'make $1 $2 $3'"
	make $1 $2 $3
	log "[READY] executing 'make $1 $2 $3'"
}

prepare_build()		# check possible values via:
{			# weimarnetz/openwrt-build/mybuild.sh set_build list
	local action

	case "$@" in
		*" "*)
			log "list: '$@'"
		;;
	esac

	for action in "$@"; do {
		log "[START] invoking: '$action' from '$@'"

		case "$action" in
			r[0-9]|r[0-9][0-9]|r[0-9][0-9][0-9]|r[0-9][0-9][0-9][0-9]|r[0-9][0-9][0-9][0-9][0-9])
				REV="$( echo "$action" | cut -d'r' -f2 )"
				log "switching to revision r$REV"
				git stash
				git checkout "$( git log -z | tr '\n\0' ' \n' | grep "@$REV " | cut -d' ' -f2 )" -b r$REV
				continue
			;;
		esac

		weimarnetz/openwrt-build/mybuild.sh set_build "$action"
		log "[READY] invoking: '$action' from '$@'"
	} done
}

show_args()
{
	local word

	for word in "$@"; do {
		case "$word" in
			*" "*)
				echo -n " '$word'"
			;;
			*)
				echo -n " $word"
			;;
		esac
	} done
}

[ -e "/tmp/apply_profile.code.definitions" ] || {
	log "please make sure, that you have placed you settings in '/tmp/apply_profile.code.definitions'"
	log "otherwise i'll take the community-settings"
	sleep 5
}

changedir release
clone "git://nbd.name/openwrt.git"
clone "git://nbd.name/packages.git"
changedir openwrt
clone "git://github.com/weimarnetz/weimarnetz.git"

prepare_build "reset_config"
mymake package/symlinks
prepare_build "$@"
mymake defconfig

for SPECIAL in unoptimized kcmdlinetweak; do {
	case "$@" in
		*"$SPECIAL"*)
			prepare_build $SPECIAL
		;;
	esac
} done

weimarnetz/openwrt-build/mybuild.sh applymystuff

#strip blank lines and comments on low mem devices to save flash and ram
case "$@" in
	*"Linksys"*)
		#remove comments
		log "remove comments from init.d"
		for f in `dir -d package/base-files/files/etc/init.d/*` ; do cat $f | sed -e 's/#[^!].*$//' > test; mv test $f; done
		#remove blank lines
		log "remove blank lines from init.d"
		#for f in `dir -d package/base-files/files/etc/init.d/*` ; do cat $f | sed -e '/^$/d' > test; mv test $f; done
		#remove comments
		log "remove comments from kalua"
		for f in `dir -d package/base-files/files/etc/kalua/*` ; do cat $f | sed -e 's/#[^!].*$//' > test; mv test $f; done
		#remove blank lines
		log "remove blank lines from kalua"
		#for f in `dir -d package/base-files/files/etc/kalua/*` ; do cat $f | sed -e '/^$/d' > test; mv test $f; done
	;;
esac



weimarnetz/openwrt-build/mybuild.sh make

log "please removing everything via 'rm -fR release' if you are ready"
log "# buildstring: $( show_args "$@" )"

