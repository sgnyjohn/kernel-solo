#!/initrd/ash
#
# LiveCD startup (init) script for AUSTRUMI
# Copyright (C) 2006-2009, Andrejs Meinerts <inni96@inbox.lv>
# $Id: init,v 2.2 20.10.2010
#


# ou Andrei Meinerts
# https://kursors.lv/2014/04/07/lietotajiem-pieejama-jaunaka-austrumi-linux-testa-versija/

# ultimo download q encontrei
# http://mint.linux.edu.lv/austrumi/
# whois linux.edu.lv -> Name: Latvijas Universitate Email: dnsadmin@serviss.lu.lv


export PATH=/initrd

############# ---[ Library functions ]---############# 

echo_green() {
echo -e "\033[40;32m* \033[0m"$1
}

echo_red() {
echo -e "\033[40;31m* \033[0m"$1
}

find_austrumi() {
if [ $? != 0 ]; then rmdir $CD; continue; fi
if test -f $CD/austrumi/austrumi.fs; then
	echo "    Austrumi found at $device"
	mounted=$device
	break
else
	umount $CD 2>/dev/null
	rmdir $CD 2>/dev/null
fi
}

find_usb() {
# fdisk -l | grep ^/dev | cut -c6-9
for device in `cat /proc/partitions | grep -v loop | grep -v ram | grep -v sr | awk '{print $4}'`; do
	CD=/mnt/$device; mkdir -p $CD
	mount /dev/$device $CD 2>/dev/null
	find_austrumi
done
}

find_sr() {
for device in `cat /proc/sys/dev/cdrom/info | grep "drive name:" | cut -d ":" -f 2`; do
	CD=/mnt/$device; mkdir -p $CD
	mount -t auto -o ro /dev/$device $CD 2>/dev/null
	find_austrumi
done
}

test_mounted() {
if test -z $mounted; then
	echo_red "Austrumi not found. Press ENTER to continue. "
	read junk; exec ash
fi
}

mount_loop() {
	losetup /dev/loop0 $1/austrumi.fs
	mount -r /dev/loop0 $LOOP
}

############# ---[ End of library functions ]---############# 

echo -e "\033[40;36m[stage1] \033[0m"

mount -t proc none /proc
mount -t sysfs none /sys
#sem logs do kernel
echo 0 > /proc/sys/kernel/printk

echo_green "Create block and character devices"
# mdev é parte do busybox
mdev -s

#onde fica montado o SFS
LOOP=/mnt/.loop
#onde fica a copia na RAM SFS
RAM=/mnt/.ramdisk

BOOT_TYPE=livecd; RUN_LEVEL=4; CACHE=yes; UNION_FS=yes; EMB_USER=no; NO_PROP=no
for x in $(cat /proc/cmdline); do
	if [ $x = dousb ]; then BOOT_TYPE=usb
	elif [ $x = nocache ]; then CACHE=no
	elif [ $x = emb_user ]; then EMB_USER=yes
	elif [ $x = text ]; then RUN_LEVEL=3
	elif [ $x = noaufs ]; then UNION_FS=no
	elif [ $x = noprop ]; then NO_PROP=yes; fi
done

if [ $BOOT_TYPE = usb ]; then
	echo_green "USB version"
	find_usb
	if test -z $mounted; then echo "Initializing USB drive: "; sleep 1; mdev -s; find_usb; fi
	if test -z $mounted; then echo "          1"; sleep 1; mdev -s; find_usb; fi
	if test -z $mounted; then echo "          2"; sleep 3; mdev -s; find_usb; fi
	if test -z $mounted; then echo "          3"; sleep 6; mdev -s; find_usb; fi
	if test -z $mounted; then echo "          4"; sleep 6; mdev -s; find_usb; fi
	if test -z $mounted; then echo "          5"; sleep 9; mdev -s; find_usb; fi
	if test -z $mounted; then echo "          6"; sleep 12; mdev -s; find_usb; fi
	if test -z $mounted; then echo "          7"; sleep 15; mdev -s; find_usb; fi
	test_mounted
else
	echo_green "LiveCD version"
	find_sr
	if test -z $mounted; then echo "Initializing CD/DVD drive: "; sleep 1; mdev -s; find_sr; fi
	if test -z $mounted; then echo "          1"; sleep 1; mdev -s; find_sr; fi
	if test -z $mounted; then echo "          2"; sleep 1; mdev -s; find_sr; fi
	if test -z $mounted; then echo "          3"; sleep 1; mdev -s; find_sr; fi
	if test -z $mounted; then echo "          4"; sleep 1; mdev -s; find_sr; fi
	if test -z $mounted; then echo "          5"; sleep 1; mdev -s; find_sr; fi
	if test -z $mounted; then echo "          6"; sleep 1; mdev -s; find_sr; fi
	if test -z $mounted; then echo "          7"; sleep 1; mdev -s; find_sr; fi
	test_mounted
fi

# possui um modelo de RAIZ,...
echo_green "Unpack austrumi.tgz"
gunzip -c $CD/austrumi/austrumi.tgz | tar xf -

# copia SFS para a RAM?
if [ $CACHE = yes ]; then mkdir -p $RAM
	echo_green "Copy austrumi.fs to RAM"
	# cp -R $CD/austrumi/austrumi.fs $RAM
	dd if=$CD/austrumi/austrumi.fs bs=8M conv=sync,noerror > $RAM/austrumi.fs 2>/dev/null
	mount_loop $RAM
	umount $CD; rm -rf $RAM $CD
	if [ $BOOT_TYPE = livecd ]; then echo -e "cdrom="$device"\nCDCACHE=yes" >>/etc/sysconfig/conf; fi
else
	mount_loop $CD/austrumi
fi

#ao invés de chroot ele cria os mesmos dirs que tem no sfs 
# e mounta com aufs um por um.
# outros diretórios são direto na RAM
#
# cria dirs = SFS
for dir in `ls $LOOP`; do test -d $LOOP/$dir && mkdir -p /$dir; done

if [ $UNION_FS = no ]; then
	#sem union, os dir no sfs ficam RO.
	for dir in `ls $LOOP`; do mount --bind $LOOP/$dir /$dir; done
	umount $LOOP; rm -rf $LOOP
else
	for dir in `ls $LOOP`; do
		# monta aufs cada DIR
		if grep -q "aufs" /proc/filesystems; then
			#aufs
			mount -t aufs none -o dirs=$dir:$LOOP/$dir=ro /$dir
		else
			#overlay? ...
			WORKDIR=/mnt/.workdir/$dir; UPPERDIR=/mnt/.upperdir/$dir; mkdir -p $WORKDIR $UPPERDIR
			mount -t overlay none -o workdir=$WORKDIR,upperdir=$UPPERDIR,lowerdir=$LOOP/$dir /$dir
		fi
	done
fi

if [ ! -f /sbin/init ]; then echo_red "/sbin/init not found! Press ENTER to continue. "; read junk; exec ash; fi

cp -r /etc/skel/. /root

if [ $EMB_USER = yes ]; then
	USERDIR=/home/austrumi
	if [ ! -f $USERDIR/.xinitrc ]; then mkdir -p $USERDIR; cp -r /etc/skel/. $USERDIR; fi
	chmod 711 $USERDIR; chown -R 500:100 $USERDIR
	sed -i 's/autologin=root/autologin=austrumi/' /etc/lxdm/lxdm.conf
	cat >> /etc/passwd << eof
austrumi:x:500:100:User,,,:/home/austrumi:/bin/bash
eof
	cat >> /etc/shadow << eof
austrumi:VNaGQcDtjXoQU:14230:0:99999:7:::
eof
fi

#rm -rf init
#exec chroot . /sbin/init $RUN_LEVEL </dev/console >/dev/console 2>&1

rm -rf init initrd
# executa binario /sbin/init
exec /sbin/init $RUN_LEVEL


