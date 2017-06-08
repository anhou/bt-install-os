# BT Install Ubuntu 14.04 by RackHD

All steps have been validated in RackHD based on Ubuntu 14.04 and 16.04

## Install Opentracker and Transmission in RackHD Server
### Install Transmission

```
$ sudo apt-get install transmission-daemon
$ sudo apt-get install transmission-cli
```

### Install Opentracker with opentracker-installer

## Prepare Ubuntu 14.04 image seed and torrent file
### Download Ubuntu 14.04 image as the seed
Downloading ubuntu-14.04.4-server-amd64.iso and copy to transmission as the seed
```
$ sudo cp ubuntu-14.04.4-server-amd64.iso /var/lib/transmission-daemon/downloads/
```
### Prepare torrent for ubuntu-14.04.4-server-amd64.iso
```
$ transmission-create -o ubuntu-14.04.torrent -c "For RackHD" -t http://172.31.128.1:6969/announce ./ubuntu-14.04.4-server-amd64.iso
$ sudo cp ubuntu-14.04.torrent /var/renasar/on-http/static/http/
```

### Prepare Customized microkernel
Prepare customized kernel and initrd
``
$ mkdir /var/renasar/on-http/static/http/andrew
$ sudo cp vmlinuz /var/renasar/on-http/static/http/andrew/
$ sudo cp initrd.gz /var/renasar/on-http/static/http/andrew/
$ sudo cp dists/ /var/renasar/on-http/static/http/andrew/ -rf
```

### Modify RackHD to be suitable for BT installation
* Change RackHD codes to be suitable for BT installation
* Restart on-http to make change take effect

## Disocver Node and Install Ubuntu 14.04 on it
* Discover node and set obm
* Prepare payload for BT Ubuntu installation
```
{
    "options": {
        "defaults": {
            "version": "trusty",
            "repo": "http://172.31.128.1:9080/andrew",
            "baseUrl": "/",
            "rootPassword": "root12345"
        }
    }
}
```
* Run API to Install Ubuntu 14.04 on node


