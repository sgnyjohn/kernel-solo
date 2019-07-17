#!/bin/sh

ls $drr/sis
log "foi...$drr/sis" 3
rdist="$drr/sis/${rootPath}"
if ! test -d $rdist ; then
 erro "ERRO dir distrib $rdist nao encontrado!" 
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
