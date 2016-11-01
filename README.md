# pifactory
Test scripts to build Raspbery Pi images using PDK


Setup:
```
git clone https://github.com/obbardc/pifactory
```

Make a base image:
```
sudo ./pifactory/pifactory_setup.sh debian-jessie-baseimage.qcow2 builder jessie
sudo chown $USER:$USER debian-jessie-baseimage.qcow2
```


Block access to the VM port (8162) from the outside world:
```
sudo iptables -A INPUT -p tcp --destination-port 8162 -j DROP
```


Start the base image:
```
qemu-system-x86_64 -hda debian-jessie-baseimage.qcow2 -boot d -m 256 -net user,hostfwd=tcp::8162-:22 -net nic
```


todo list:
 > Get a list of required packages
 > Debianize as part of PDK source package
 > root password asked for in pifactory_setup.sh
 > guest reboots after grub starts