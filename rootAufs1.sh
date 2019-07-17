#!/usr/bin/ash
# signey john jun/2012
# archlinux initramfs hook

root=${root//,/ }
log "root=$root" 10
for i in $root; do
	#comeca com /?
	if [ $(echo "===${i}"|grep "===/") ]; then
		x=0
	else
		i=$rdist/$i
	fi
	log "$nm $i" 5

	if test -d $i; then
		d=$i
	else
		d=$drr/r_$nm
		nm="${nm}0"
		#$(echo $nm+1|busybox bc)
		mkDir $d
		if test -b $i; then
			mount $i $d
			if [ $? -ne 0 ]; then
				erro "ERRO mount $i $d"
			fi	
		elif test -f $i; then
			mount -o loop $i $d
			if [ $? -ne 0 ]; then
				erro "ERRO mount -o loop $i $d"
			fi	
		elif test -d $i; then
			d=$d
		else
			erro "ERRO nao existe $i" 
		fi
	fi
	# primeiro sempre rw, o resto ro
	if [ ".$opAufs" == "." ]; then
		opAufs="$d=rw"
	else
		opAufs="$opAufs:$d=rr"
	fi	
done
log "ROOTaufs=$opAufs" 
mount -t aufs -o noatime,dirs=$opAufs aufs $rdest
ls $rdest
log "foi...aufs $rdest" 10
mount /dev/disk/by-label/SISTS $rdest/mnt/initrd/sis

mount /dev/disk/by-label/tmp $rdest/tmp

mkdir $rdest/run/initramfs
echo 1 > $rdest/run/initramfs/fsck-root

# vim: set ft=sh ts=4 sw=4 et:
