###############

echo "Installing Dependencies"

silent() { "$@" >/dev/null 2>&1; }

silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

cd /root

mknod /dev/kvm c 10 232
chmod 777 /dev/kvm
chown root:kvm /dev/kvm

apt-get install qemu-system python3 fdisk mtools -y

VERSION_KVM_OPENCORE="v21"
REPO_KVM_OPENCORE="https://github.com/thenickdude/KVM-Opencore"
wget $REPO_KVM_OPENCORE/releases/download/$VERSION_KVM_OPENCORE/OpenCore-$VERSION_KVM_OPENCORE.iso.gz -O opencore_kvm.iso.gz

gzip -dk opencore_kvm.iso.gz
mkdir -p extract
START=$(sfdisk -l opencore_kvm.iso | grep -i -m 1 "EFI System" | awk '{print $2}')
mcopy -bspmQ -i "opencore_kvm.iso@@${START}S" ::EFI "extract"

wget https://github.com/dockur/macos/raw/refs/heads/master/assets/default.plist -O extract/EFI/OC/config.plist

SIZE=$(( 256*1024*1024 ))
TOTAL=$(( SIZE-(34*512) ))
LAST_LBA=$(( TOTAL/512 ))
COUNT=$(( LAST_LBA-(2048-1) ))
truncate -s "$SIZE" "OpenCore.img"
{   echo "label: gpt"
    echo "label-id: 1ACB1E00-3B8F-4B2A-86A4-D99ED21DCAEB"
    echo "device: OpenCore.img"
    echo "unit: sectors"
    echo "first-lba: 34"
    echo "last-lba: $LAST_LBA"
    echo "sector-size: 512"
    echo ""
    echo "OpenCore.img1 : start=2048, size=$COUNT, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=05157F6E-0AE8-4D1A-BEA5-AC172453D02C, name=\"primary\""
} > partition.fdisk
sfdisk -q "OpenCore.img" < partition.fdisk

OFFSET=$(( 2048*512 ))
echo "drive c: file=\"OpenCore.img\" partition=0 offset=$OFFSET" > /etc/mtools.conf
mformat -F -M "512" -c "4" -T "$COUNT" -v "EFI" "C:"
mcopy -bspmQ "extract/EFI" "C:"

wget https://github.com/dockur/macos/raw/refs/heads/master/src/fetch.py
python3 ./fetch.py download -o .

qemu-img create -f qcow2 HD.img 100G

qemu-system-x86_64 --enable-kvm \
 -machine q35 \
 -cpu Penryn,kvm=on,vendor=GenuineIntel \
 -m 1024 \
 -usb -device usb-kbd -device usb-mouse \
 -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
 -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS.fd \
 -device virtio-blk-pci,drive=MacHDD \
 -drive id=MacHDD,if=none,format=raw,file=./OpenCore.img \
 -device virtio-blk-pci,drive=MacHDD2 \
 -drive id=MacHDD2,if=none,format=dmg,file=./BaseSystem.dmg \
 -device virtio-blk-pci,drive=MacHDD3 \
 -drive id=MacHDD3,if=none,format=raw,file=./HD.img \
 -vnc :0


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
