#!/bin/bash

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


# copia cmd e dependencias para initrd

# mount: can't setup loop device: No space left on device


#######################################
erro() {
 xxl="$debugr"
 debugr=y
 log "$1" 5
 debugr="$xxl"
}

xx=bbb
tmp=/tmp/sdoifjdsf
ldd $1 >$tmp
exec < $tmp
while read ln; do
 b=$(echo $ln|awk '{print $3}')
 if test -e "$b" ; then
   if test -e /tmp/k$b ; then
	echo "OK ja $b"
   else
	echo "OK $b";
	xx=$(echo "$b $xx");
	#echo $xx;
   fi
 else
	echo "ER $b"
 fi
 #echo $b
done

xx="noooo $xx"

echo "=====
$xx
"
