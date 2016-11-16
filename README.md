# pifactory
Test scripts to build Raspbery Pi images using PDK


Setup:
```
git clone https://github.com/obbardc/pifactory
```

Make a base image:
```
sudo ./pifactory_setup.sh debian-jessie-baseimage.qcow2 builder jessie
sudo chown $USER:$USER debian-jessie-baseimage.qcow2
```


Block access to the VM port (8162) from the outside world:
```
sudo iptables -A INPUT -p tcp --destination-port 8162 -j DROP
```

Place your Apt repo created with PDK inside a zip file called "distro_master.apt.zip"


Build your image (TBC):
```
./pifactory_build
```


todo list:
* Get a list of required packages
* Debianize as part of PDK source package
* guest reboots after grub starts, although this is not too much of a problem
* debootstrap option "--variant=minbase" when making base images?
* pifactory_setup makes my computer freak out afterwards :-(
* wait for guest to shutdown cleanly before killing !
* connect using public key encryption instead of password!