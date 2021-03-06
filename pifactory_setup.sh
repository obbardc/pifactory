#!/bin/bash
#
# pifactory_setup.sh
#
# this script will setup the build environment
#
# setup like this
# sudo apt-get install qemu grub2
#
# run it like this
# sudo ./pifactory_setup.sh debian.qcow2 builder jessie
# sudo chown user:user debian.qcow2
#
# with vda drives (DO NOT USE): qemu-system-x86_64 -drive file=debiannew.qcow2,if=virtio -boot d -m 256
#
# with sda drives: qemu-system-x86_64 -hda debiannew.qcow2 -boot d -m 256
#
#
# based on code by the following authors:
# http://diogogomes.com/2012/07/13/debootstrap-kvm-image/
# https://gist.github.com/spectra/10301941
# https://gist.github.com/jalsot/a24aa543021889ad0c70
#
#
# current bugs:
#  * INCLUDES must not be empty
#
# Configs overwritable via environment variables
VSYSTEM=${VSYSTEM:=qemu}					# Either 'qemu' or 'kvm'
FLAVOUR=${FLAVOUR:=debian}					# Either 'debian' or 'ubuntu'
#INCLUDES=${INCLUDES:="dropbear"}                    # enter packages here in CSV format   # dropbair has no sftp server :-(
INCLUDES=${INCLUDES:="openssh-server"}                    # enter packages here in CSV format
MIRROR=${MIRROR:="http://ftp.uk.debian.org/debian"}
ARCH=${ARCH:=amd64}
APT_CACHER=${APT_CACHER:=no}
IMGSIZE=${IMGSIZE:=16G}             # base system takes approx. 600mb

clean_debian() {
	[ "$MNT_DIR" != "" ] && chroot $MNT_DIR umount /proc/ /sys/ /dev/ /boot/
	sleep 1s
	[ "$MNT_DIR" != "" ] && umount $MNT_DIR
	sleep 1s
	[ "$DISK" != "" ] && $VSYSTEM-nbd -d $DISK
	sleep 1s
	[ "$MNT_DIR" != "" ] && rm -r $MNT_DIR
}

fail() {
	clean_debian
	echo ""
	echo "FAILED: $1"
	exit 1
}

cancel() {
	fail "CTRL-C detected"
}

if [ $# -lt 3 ]
then
	echo "author: Kamil Trzcinski (http://ayufan.eu)"
	echo "license: GPL"
	echo "usage: $0 <image-file> <hostname> <release> [optional debootstrap args]" 1>&2
	exit 1
fi

FILE=$1
HOSTNAME=$2
RELEASE=$3
shift 3

trap cancel INT

echo "Installing $RELEASE into $FILE..."

MNT_DIR=`tempfile`
rm $MNT_DIR
mkdir $MNT_DIR
DISK=

# add apt cacher for faster rebuilds, runs on 3142
if [ "$APT_CACHER" == "yes" ]; then
    echo "Installing apt-cacher-ng for fast rebuilds"
    apt-get install apt-cacher-ng
fi

if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    $VSYSTEM-img create -f qcow2 $FILE $IMGSIZE
fi

if [ $FLAVOUR == "debian" ]; then
    BOOT_PKG="linux-image-$ARCH grub-pc"
fi

echo "Looking for nbd device..."

modprobe nbd max_part=16 || fail "failed to load nbd module into kernel"

for i in /dev/nbd*
do
	if $VSYSTEM-nbd -c $i $FILE
	then
		DISK=$i
		break
	fi
done

[ "$DISK" == "" ] && fail "no nbd device available"

echo "Connected $FILE to $DISK"

echo "Partitioning $DISK..."
sfdisk $DISK -q -D -uM << EOF || fail "cannot partition $FILE"
,200,83,*
;
EOF

echo "Creating boot partition..."
mkfs.ext4 -q ${DISK}p1 || fail "cannot create /boot ext4"

echo "Creating root partition..."
mkfs.ext4 -q ${DISK}p2 || fail "cannot create / ext4"

echo "Mounting root partition..."
mount ${DISK}p2 $MNT_DIR || fail "cannot mount /"

echo "Installing Debian $RELEASE..."
debootstrap --include=$INCLUDES $* $RELEASE $MNT_DIR $MIRROR || fail "cannot install $RELEASE into $DISK"

echo "Configuring system..."
cat <<EOF > $MNT_DIR/etc/fstab
/dev/sda1 /boot               ext4    sync 0       2
/dev/sda2 /                   ext4    errors=remount-ro 0       1
EOF

echo $HOSTNAME > $MNT_DIR/etc/hostname

cat <<EOF > $MNT_DIR/etc/hosts
127.0.0.1       localhost
127.0.1.1 		$HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat <<EOF > $MNT_DIR/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

mount --bind /dev/ $MNT_DIR/dev || fail "cannot bind /dev"
chroot $MNT_DIR mount -t ext4 ${DISK}p1 /boot || fail "cannot mount /boot"
chroot $MNT_DIR mount -t proc none /proc || fail "cannot mount /proc"
chroot $MNT_DIR mount -t sysfs none /sys || fail "cannot mount /sys"
LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get install -y --force-yes -q $BOOT_PKG || fail "cannot install $BOOT_PKG"
chroot $MNT_DIR grub-install $DISK || fail "cannot install grub"
chroot $MNT_DIR update-grub || fail "cannot update grub"
chroot $MNT_DIR apt-get clean || fail "unable to clean apt cache"
chroot $MNT_DIR sed -i 's/^PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

sed -i "s|${DISK}p1|/dev/sda1|g" $MNT_DIR/boot/grub/grub.cfg
sed -i "s|${DISK}p2|/dev/sda2|g" $MNT_DIR/boot/grub/grub.cfg

#echo "Enter root password:"
#while ! chroot $MNT_DIR passwd root
#do
#	echo "Try again"
#done

# set root password to pass
echo "root:pass" | chroot $MNT_DIR chpasswd

echo "Finishing grub installation..."
grub-install $DISK --root-directory=$MNT_DIR --modules="biosdisk part_msdos" || fail "cannot reinstall grub"

echo "SUCCESS!"
clean_debian
exit 0
