ver=4.8.0-1-amd64
ver=3.16.0-4-amd64

Mon() {
	echo "=====>>> $1"
	echo -n "enter..."; read
}

drt=/tmp/k
op=N
if test -d $drt; then
	echo -n "===> já existe $drt
	apenas atualizar init (S N) ? ";read op
fi

if [ "$op" == "N" ]; then
	## 0 - cat /etc/initramfs-tools/modules
		# List of modules that you want to include in your initramfs.
		#
		# Syntax:  module_name [args ...]
		#
		# You must run update-initramfs(8) to effect this change.
		#
		# Examples:
		#
		# raid1
		# sd_mod
	aq=/etc/initramfs-tools/modules
	lf="
	"
	for i in ntfs fuse squashfs aufs nls_utf8 nls_cp437 vfat fat ext4 reiserfs ext3 loop; do
		if [ "$(grep -v "#" $aq|grep $i)" == "" ]; then
			echo "echo $lf$i >>$aq"
			echo "$lf$i" >>$aq
			Mon
		fi 
	done


	## 1 - módulos
		#- aufs existe,atualizado ?
		#- loop aes instalado ? -  strings -a loop.ko |grep -i aes
	[ "$(find /lib/modules/$ver/ -name aufs.ko)" == "" ] && \
		Mon "ERRO aufs.ko não existe"
	[ "$(find /lib/modules/$ver/ -name loop.ko)" == "" ] && \
		Mon "ERRO loop.ko não existe"
	[ "$(find /lib/modules/$ver/ -name loop.ko|wc|awk '{print $1}')" -gt 1 ] && \
		Mon "ERRO mais de UM loop.ko"
	[ "$(strings -a $(find /lib/modules/$ver/ -name loop.ko)|grep -i aes)" == "" ] && \
		Mon "ERRO loop.ko sem AES"


	## 2 - #cria imagem "initrd" conforme parametros acima
	#	============
	mkinitramfs -o /tmp/tmp.img /lib/modules/$ver/
	ls -tlh /tmp/tmp.img
	Mon "tmp init.img ... "
		
	## 3 - #extrai o filesystem
	mkdir $drt; 
	cd $drt ; 
	7z x /tmp/tmp.img;cat tmp |cpio -di --no-absolute-filenames;
	rm -f tmp
	ls -l 
	Mon "init img extraida"

	## 4 - #adicionar comando fsck - /sbin/e2fsck e /sbin/losetup-aes-32
	ad=/tmp/lixo.tar.gz
	rm $ad
	cmt="/sbin/e2fsck /usr/bin/basename /sbin/losetup-aes-64"
	for cm in $cmt; do
		x=$(ldd $cm | while read ln; do echo $(echo $ln|awk '{print $3}');done)
		for i in $x;do b=$(readlink -e $i);if [ "$b" != "" ]; then x="$x $b";fi;done
		xf="$xf $x $cm"
	done
	echo $xf
	Mon "selecionadas libs para 
	executavies $cmt"
	tar czvf $ad $xf
	tar xzvf $ad
	cd sbin
	mv "losetup" "losetup-O"
	ln -s losetup-aes-64 losetup
	cd ..
	ls -lh $ad
	Mon "adicionado exec e libs..."	

fi


## 5 - #altera o inicializador
cd $drt
for i in proc dev sys; do ! test -e $i && mkdir $i;done
test -e init-O || mv init init-O
test -e init && rm -f init
cp -pv ~/dev/kernel-solo/init-solo-9.sh .
ln -s init-solo-9.sh init
chmod +x init-solo-9.sh 
chown root:root init-solo-9.sh
ls -l init* 
Mon "init solo implantado"

## 6 - #cria nova imagem "initrd"
cd $drt
aqd=/tmp/initrd.img-solo-$ver
rm -f $aqd $aqd.gz
find ./ | cpio -H newc -o > $aqd
gzip $aqd
ls -l $aqd.gz
Mon "criado novo initrd"
	
## 7 - kdeb package
dt=$(date +"%Y-%m-%d")
aq=/tmp/kDeb-$ver-$dt.tar.bz2
dr=/tmp/kDeb
rm -rfv $dr;mkdir $dr
cp -pv /boot/vmlinuz-$ver $dr
cp -pv $aqd.gz $dr/
cp -rpv /lib/modules/$ver/ $dr
cd /tmp
rm -f $aq
tar cjvf $aq kDeb/
ls -tl $aq
aqh=/tmp/kDeb-$ver-$dt-headers.tar.bz2
tar cjvf $aqh /usr/src
ls -lh /tmp/kDeb-*
Mon "criado novos pacotes..."

Mon "fim"
