#!/bin/sh

###########################################################################
#
#    Copyright (c) 2011/2012 Signey John
#    
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#    
###########################################################################


# 4 aceita mountLabel - montando tudo em /mnt/
# ok faz e2fsck de particoes ext? ...
# 6 compatibilidade archlinux - parte udev...

# 2014/set
# aceita no root=
# - /dev
# - @label
# (ambos com dir apos ou não...)
# aceita no root= crypto

#######################################
erro() {
 xxl="$debugr"
 debugr=y
 log "$1" 15
 debugr="$xxl"
}
##########################
# troca str1 str2 str3
trocaa() {
	ret=$(echo "$1"| bin/awk '{ gsub(/'$2'/, "'$3'"); print }')
}
##########################
# troca str1 str2 str3
troca() {
	ret=${1//$2/$3}
}
#######################################
log() {
 echo "$1"
 if [ $2 ] && [ $debugs ]; then
  sleep $2
 elif [ $2 ] && [ $debugr ]; then
  echo "enter..."
  read xent
  while [ ".$xent" != "." ]; do
	$xent
	read xent
  done
 fi
}
#######################################
mkDir() {
 if ! test -e $1 ; then
  mkdir $1
 fi
}
#######################################
#cheka part recebe label...
Fsck() {
 if [ ".$(blkid | grep ${1} | grep 'TYPE=\"ext')" != "." ]; then
  log "e2fsck /dev/disk/by-label/${1} .... " 2
  /sbin/e2fsck -p -v "/dev/disk/by-label/${1}"
 fi
}
#######################################
#monta /dev ou label
montar() {
	local lb=$1
	local md=mount
	local lp=/sbin/losetup
	if [ ".$(blkid | grep ${lb} | grep ntfs)" != "." ]; then
	 modprobe -v ntfs
	 for xx in /sbin/mount.ntfs-3g /sbin/ntfs-3g; do
	  if test -x "$xx"; then
	    log "ntfs $xx .... " 2
		md="$xx"
		break
	  fi
	 done
	fi
	#monta dev...(precisa criar /mnt/initrd/dev)
	if [ $(echo "===${lb}"|grep "===/") ]; then
		local mor=$lb
	else 
		local mor="/dev/disk/by-label/${lb}"
	fi
	#crypto
	if [ "$psw" != "" ] && [  "$(echo ",$pswI,"|grep ",$lb,")" == ""  ]; then
		local mor1=$($lp -f)
		echo "$(echo -n "$psw"|md5sum|awk '{print $1}')"|$lp -p 0 -e AES256 $mor1 $mor
		log "$lp -p 0 -e AES256 $mor1 $mor" 2
		mor=$mor1
	fi
	#cheka
	Fsck $lb
	#monta
	$md $mor $2
	if [ $? -ne 0 ]; then
		erro "ERRO: $md $mor $2"
	fi
}

#######################################
#######################################
# script inicio
#######################################
bb=/bin/busybox
if test -e $bb ; then
	$bb --install -s
fi

#sj - copiado debian
echo "Loading, please wait..."

# Default PATH differs between shells, and is not automatically exported
# by klibc dash.  Make it consistent.
export PATH=/sbin:/usr/sbin:/bin:/usr/bin

[ -d /dev ] || mkdir -m 0755 /dev
[ -d /root ] || mkdir -m 0700 /root
[ -d /sys ] || mkdir /sys
[ -d /proc ] || mkdir /proc
[ -d /tmp ] || mkdir /tmp
mkdir -p /var/lock
mount -t sysfs -o nodev,noexec,nosuid sysfs /sys
mount -t proc -o nodev,noexec,nosuid proc /proc

# Note that this only becomes /dev on the real filesystem if udev's scripts
# are used; which they will be, but it's worth pointing out
tmpfs_size="10M"
if [ -e /etc/udev/udev.conf ]; then
	. /etc/udev/udev.conf
fi
if ! mount -t devtmpfs -o size=$tmpfs_size,mode=0755 udev /dev; then
	echo "W: devtmpfs not available, falling back to tmpfs for /dev"
	mount -t tmpfs -o size=$tmpfs_size,mode=0755 udev /dev
	[ -e /dev/console ] || mknod -m 0600 /dev/console c 5 1
	[ -e /dev/null ] || mknod /dev/null c 1 3
fi
mkdir /dev/pts
mount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts || true
mount -t tmpfs -o "nosuid,size=20%,mode=0755" tmpfs /run
mkdir -m 0755 /run/initramfs

# Export the dpkg architecture
export DPKG_ARCH=
. /conf/arch.conf

#sj - fim copiado debian

##########################################
echo "# Parse command line options"
#padroes
rootLabel="boot"
rootPath=
runLevel=2
init=/sbin/init
#possivel opcoes
opV="chr debug debugr debugs debugl debugx rootLabel rootPath root runLevel"
opV="$opV init mountLabel modProbe semGpu psw"
for x in $(cat /proc/cmdline); do
	oo=0
	for i in $opV BOOT_IMAGE; do
		#é uma atribuição ?
		if [ $(echo "===${x}"|grep "===${i}=") ]; then
			echo "  $x"
			eval $x
			oo=1
			break
		elif [ ".$x" == ".$i" ] ; then
			eval "$x=y"
			oo=1
			break
		fi
	done
	if [ $oo -eq 0 ]; then
		log "  **boot: opcao $x invalida
  **opcoes validas: $opV
  **ENTER para continuar...
  *************************" 5
		#read
	fi
	if [ "$x" == "psw" ]; then
		echo -n "polling idle threads "
		read psw
	fi
	if [ "$x" == "debugl" ]; then
		debugL=/initrd.log
		debug=y
		quiet=n
		exec >$debugL 2>&1
		set -x
	fi
	if [ "$x" == "semGpu" ]; then
		rm -rf "/lib/modules/$(uname -r)/kernel/drivers/gpu"
	fi
done
log "rootLabel=$rootLabel" 
log "rootPath=$rootPath" 3


for i in 1 2 3 4 5 6; do
	[ -c /dev/tty$i ] || mknod /dev/tty$i c 4 $i
done
#/scripts/init-top/console_setup


#######################################
# Start the udev daemon to process events
ud=0
if test -e /sbin/udevd; then
	# It's all over netlink now
	echo "" > /proc/sys/kernel/hotplug
	ud=1
	/sbin/udevd --daemon --resolve-names=never
	# Iterate sysfs and fire off everything; if we include a rule for it then
	# it'll get handled; otherwise it'll get handled later when we do this again
	# in the main boot sequence.
	( /sbin/udevadm trigger --subsystem-match=block; \
	  /sbin/udevadm trigger --subsystem-nomatch=block; ) &
	  
elif test -e /usr/lib/udev/udevd; then
	ud=2
	/usr/lib/udev/udevd --daemon --resolve-names=never
	/usr/bin/udevadm trigger --action=add --type=subsystems
	/usr/bin/udevadm trigger --action=add --type=devices
	/usr/bin/udevadm settle

elif test -e /lib/systemd/systemd-udevd; then
	#para 3.16...
	if [ -w /sys/kernel/uevent_helper ]; then
		echo > /sys/kernel/uevent_helper
	fi

	/lib/systemd/systemd-udevd --daemon --resolve-names=never

	udevadm trigger --action=add
	udevadm settle || true

	if [ -d /sys/bus/scsi ]; then
		modprobe -q scsi_wait_scan && modprobe -r scsi_wait_scan || true
		udevadm settle || true
	fi

elif test -e /lib/systemd/systemd-udevd; then
	log "uDEV systemd ..." 10
	xu=/lib/systemd/systemd-udevd
	tmpfs_size="10M"
	if [ -e /etc/udev/udev.conf ]; then
		. /etc/udev/udev.conf
	fi
	if ! mount -t devtmpfs -o size=$tmpfs_size,mode=0755 udev /dev; then
		echo "W: devtmpfs not available, falling back to tmpfs for /dev"
		mount -t tmpfs -o size=$tmpfs_size,mode=0755 udev /dev
		[ -e /dev/console ] || mknod -m 0600 /dev/console c 5 1
		[ -e /dev/null ] || mknod /dev/null c 1 3
	fi	

else
	erro "udevd nao encontrado, sem hard detect/events..."
fi

log "udev $ud OK?" 10
 

################################################
## modprobe
################################################  
#falta colocar blkid e carregar os necessários...
modprobe -v vfat
#modprobe -v ntfs
modprobe -v ext3
modprobe -v ext4
modprobe -v aufs
modprobe -v btrfs
modprobe -v loop #debian precisa
modprobe -v squashfs
###############################
#modprobe na mao
if [ ".$modProbe" != "." ]; then
	troca "$modProbe" ',' ' ';modProbe=$ret
	for i in $modProbe; do
		echo $i
		modprobe -v $i
	done
	log "mod probe ok $modProbe" 3
fi
log "probes" 3


mkDir /mnt
drr=/mnt/initrd
mkDir $drr
mkDir $drr/sis
mkDir $drr/dev
rdist="$drr/sis/${rootPath}"

## rootLabel ?
if [ "$rootLabel" != "" ]; then

	echo "################################"
	echo "espera por LABEL $rootLabel"
	x="."
	while ! test -e "/dev/disk/by-label/${rootLabel}"; do
		echo $x
		x=".$x"
		sleep 1
		#ls /dev/disk/by-label
	done
	echo "################################"
	montar $rootLabel $drr/sis

	#init EXTERNO?
	if test -e $drr/sis/init.sh; then
		. $drr/sis/init.sh
	fi

	ls $drr/sis
	log "foi...$drr/sis" 3
	if ! test -d $rdist ; then
	 erro "ERRO dir distrib $rdist nao encontrado!" 
	fi

fi

#####################################
#montar outros
log "mountLabel=$mountLabel"
if ! test -z $mountLabel ; then
	log "1mountLabel=$mountLabel"
	troca "$mountLabel" ';' ' '
	troca "$ret" ',' ' '
	mountLabel=$ret
	for i in $mountLabel; do
		log "i=$i - mountLabel=$mountLabel"
		
		#ver pasta destino
		if [ $(echo "===${i}"|grep "===/") ]; then
			pd=$(basename $i)
		else 
			pd=$i
		fi		
		if ! test -e $drr/$pd; then mkdir $drr/$pd;fi
		log "***************** montar $i $drr/$pd"
		montar $i $drr/$pd
	done
fi

##monta o file system root
if [ ".$root" == "." ]; then
 root=$(cat $rdist/fstab)
else
	troca "$root" ';' ' '
	troca "$ret" ',' ' '
	root=$ret
fi

##################################
# monta roots para aufs
nm=0
opAufs=""
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
mount -t aufs -o noatime,dirs=$opAufs aufs /root
ls /root
log "foi...aufs /root" 30

#move tudo para novo ROOT
# ao shutdown loop nao pode desmontar raiz porque
# raiz depende de mounts q estao dentro dela...
mkDir /root/mnt
mkDir /root/mnt/initrd
for i in $drr/*; do
 x=$(basename $i)
 mkDir /root/mnt/initrd/$x
 mount -n -o move $i /root/mnt/initrd/$x
done

#debugl
if [ $debugL ]; then
 mkDir /root/var
 mkDir /root/var/log
 mv $debugL /root/var/log
fi

log "##############################
moveu monts..." 30


#se nao matar o X fica sem mouse, teclado...
pkill udevd
killall udevd


# Move virtual filesystems over to the real filesystem
mount -n -o move /dev /root/dev
#mount -n -o bind /dev /root/dev
mount -n -o move /sys /root/sys
mount -n -o move /proc /root/proc
log "foi...mount -n -o move rootmnt=/root
@=$@" 20

#br-abnt2
#chroot /root /usr/sbin/install-keymap us
#echo "foi...teclado"
#sleep 3

#parte inutil, fixar em run-init... ou setado..
if [ ".$chr" == "." ]; then
 for d in bin sbin; do
  for i in run-init switch_root; do
   ch=/$d/$i
   if test -x $ch ; then
    chr=$ch
    break
   fi
  done
  if [ ".$chr" != "." ]; then
   break
  fi
 done
fi


log "chroot para == $chr /root $init $runLevel " 10
exec $chr /root $init $runLevel  </root/dev/console >/root/dev/console 2>&1
echo "Could not execute run-init."
exit


#exec switch_root /root /sbin/init 2
#exec run-init /root ${init} "$@" </root/dev/console >/root/dev/console 2>&1
#ls /root/bash
#exec /bin/busybox chroot /root /sbin/init 2
