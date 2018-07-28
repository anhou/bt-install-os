
# Steps
* 获取ubuntu-14.04.4-server-amd64.iso里的initrd.gz `./install/netboot/ubuntu-installer/amd64/initrd.gz`
    - 用 `./install/netboot/ubuntu-installer/amd64/initrd.gz` 的原因是因为里面有一些网络的初始化已经做过了，在这个基础上修改initrd.gz让其可以BT下载然后mount ISO文件本地安装 比较容易
    - mount ISO 相关的文件则从 ubuntu-14.04.4-server-amd64.iso目录下的 "./install/initrd.gz" copy而来，也是为了利用现成的程序，做比较小的改动就可以实现功能
* 解压initrd.gz
* 集成transimission 到 initrd
* 在initrd中修改其他必要的代码
* 压缩initrd.gz


# 解压initrd.gz
* mount -o loop buntu-14.04.4-server-amd64.iso 到一个文件夹
* 解压
```
$ mkdir ~/ubuntu_iso_net_initrd
$ cp ./install/netboot/ubuntu-installer/amd64/initrd.gz ~/ubuntu_iso_net_initrd/
$ cd ~/ubuntu_iso_net_initrd
$ gunzip initrd.gz
$ ls
initrd
$ sudo cpio -idmv < ./initrd
```

# 修改initrd
## 编译 transmission 并 集成到initrd
* 如果源码编译 transmission 请参考 transmission 相关资料
* copy transmission tools

```
$ sudo cp ~/transmission-2.92/utils/transmission-show ~/ubuntu_iso_net_initrd
$ sudo cp ~/transmission-2.92/daemon/transmission-daemon ~/ubuntu_iso_net_initrd/usr/bin/ -srfL
$ sudo cp ~/transmission-2.92/daemon/transmission-remote ~/ubuntu_iso_net_initrd/usr/bin/ -rfL
$ sudo mkdir ~/ubuntu_iso_net_initrd/etc/transmission-daemon/
$ sudo cp /etc/transmission/settings.json ~/ubuntu_iso_net_initrd/etc/transmission-daemon/ (因为在initrd,"download-dir" "incomplete-dir"都指定为"/",其他的和另一台seed server是一样的)
```

* copy library for transmission
    - 在这个例子中，这些文件主要来自ubuntu 14.04，下面的来源只是之前copy过去的

```
$ sudo cp ../ubuntu_initrd/lib/x86_64-linux-gnu/ ./lib/ -rfL
$ sudo cp ../ubuntu_initrd/usr/lib/x86_64-linux-gnu/ ./usr/lib/ -rfL
```

## 修改cdrom相关

* ubuntu-14.04.4-server-amd64.iso目录下"./install/initrd.gz"解压到"~/ubuntu_iso_initrd"

```
$ sudo cp ~/ubuntu_iso_initrd/var/lib/dpkg/info/load-cdrom.postinst ~/ubuntu_iso_net_initrd/var/lib/dpkg/info/
$ sudo cp ~/ubuntu_iso_initrd/var/lib/dpkg/info/load-cdrom.templates ~/ubuntu_iso_net_initrd/var/lib/dpkg/info/
```

* copy cdrom-retriever

```
$ sudo cp ~/ubuntu_iso_initrd/usr/lib/debian-installer/retriever/cdrom-retriever ~/ubuntu_iso_net_initrd/usr/lib/debian-installer/retriever/
```

* change or copy status file in `ubuntu_iso_net_initrd`

```
--- ubuntu_initrd_back/var/lib/dpkg/status      2016-11-01 22:32:20.591865693 -0400
+++ ubuntu_iso_net_initrd/var/lib/dpkg/status   2016-11-09 00:52:36.515279089 -0500
@@ -35,13 +35,6 @@
 Version: 2.19-0ubuntu6
 Description: Embedded GNU C Library: NSS helper for DNS - udeb

-Package: download-installer
-Status: install ok unpacked
-Version: 1.37ubuntu1
-Depends: cdebconf-udeb, net-retriever, anna (>= 1.07)
-Description: Download installer components
-Installer-Menu-Item: 2300
-
 Package: lowmemcheck
 Status: install ok unpacked
 Version: 1.40ubuntu1
@@ -99,12 +92,26 @@
 Depends: libnl-3-200-udeb (= 3.2.21-1), libc6-udeb (>= 2.17)
 Description: library for dealing with netlink sockets - generic netlink

-Package: choose-mirror
+Package: bt-download
 Status: install ok unpacked
 Version: 2.55ubuntu1
-Depends: configured-network, choose-mirror-bin
-Description: Choose mirror to install from (menu item)
-Installer-Menu-Item: 2300
+Depends: configured-network
+Description: BT download (menu item)
+Installer-Menu-Item: 2200
+
+Package: cdrom-retriever
+Status: install ok unpacked
+Version: 1.35
+Provides: retriever
+Depends: cdebconf-udeb, bt-download
+Description: Fetch modules from a CDROM
+
+Package: load-cdrom
+Status: install ok unpacked
+Version: 1.35
+Depends: cdebconf-udeb, cdrom-retriever, anna (>= 1.07)
+Description: Load installer components from CD
+Installer-Menu-Item: 2400

 Package: biosdevname-udeb
 Status: install ok unpacked
@@ -381,7 +388,7 @@
 Status: install ok unpacked
 Version: 1.37ubuntu1
 Provides: retriever
-Depends: libc6-udeb (>= 2.18), libdebian-installer4-udeb (>= 0.88ubuntu2), cdebconf-udeb, choose-mirror, configured-network, di-utils (>= 1.58), gpgv-udeb, ubuntu-keyring-udeb
+Depends: libc6-udeb (>= 2.18), libdebian-installer4-udeb (>= 0.88ubuntu2), cdebconf-udeb, configured-network, di-utils (>= 1.58), gpgv-udeb, ubuntu-keyring-udeb
 Description: Fetch modules from the Internet

 Package: kickseed-common
@@ -435,12 +442,6 @@
 Depends: libc6-udeb (>= 2.18), libdebconfclient0-udeb, libdebian-installer4-udeb (>= 0.88ubuntu2), cdebconf-udeb
 Description: anna's not nearly apt, but for the Debian installer, it will do

-Package: choose-mirror-bin
-Status: install ok unpacked
-Version: 2.55ubuntu1
-Depends: libc6-udeb (>= 2.18), libdebconfclient0-udeb, libdebian-installer4-udeb (>= 0.88ubuntu3), cdebconf-udeb
-Description: Choose mirror to install from (program)
-
 Package: pcmciautils-udeb
 Status: install ok unpacked
 Version: 018-8
```

* copy cdrom-detect (来自ubuntu-14.04.4-server-amd64.iso里的install/initrd.gz) to bt-download
```
$ sudo cp ~/ubuntu_iso_initrd/var/lib/dpkg/info/cdrom-detect.postinst ~/ubuntu_iso_net_initrd/var/lib/dpkg/info/bt-download.postinst
$ sudo cp ~/ubuntu_iso_initrd/var/lib/dpkg/info/cdrom-detect.templates ~/ubuntu_iso_net_initrd/var/lib/dpkg/info/bt-download.templates
```

* modify bt-download.postinst, the content is as below
    - NOTE:
        - 要去一个地方下载已经准备好的torrent文件
            - 在RackHD中，这个前面已经设置过了 `wget 172.31.128.1:9080/ubuntu-14.04.torrent`

```
$ vi ~/ubuntu_iso_net_initrd/var/lib/dpkg/info/bt-download.postinst (to modify, to see)
```

```shell
#!/bin/sh -e

set -e
. /usr/share/debconf/confmodule

wget 172.31.128.1:9080/ubuntu-14.04.torrent
transmission-daemon
sleep 5
transmission-remote -n 'transmission:transmission' -a /ubuntu-14.04.torrent

DOWNLOADED_FILE=`transmission-show ubuntu-14.04.torrent | grep Name | /busybox-x86_64 awk 'BEGIN{FS=": "}{print $2}' | head -n 1`

while true
do
    sleep 1
    PERCENTAGE=`transmission-remote -n 'transmission:transmission' -l | grep $DOWNLOADED_FILE | /busybox-x86_64 awk 'BEGIN{FS=" "}{print $2}'`
    echo $PERCENTAGE
    if [ $PERCENTAGE = "100%" ]
    then
        break
    fi
done

echo "BT downloading finished"

mkdir /cdrom
mount -t iso9660 /Downloads/$DOWNLOADED_FILE /cdrom/
echo "$DOWNLOADED_FILE is mounted"


#log() {
#       logger -t bt-download "$@"
#}

# Set the suite and codename used by base-installer and base-config
# to the suite/codename that is on the CD. In case there are multiple
# suites, prefer the one in default-release.
set_suite_and_codename() {
        for dir in $(cat /etc/default-release) $(ls -1 /cdrom/dists/); do
                echo "andrew 111111"
                relfile="/cdrom/dists/$dir/Release"
                if [ -e $relfile ]; then
                        suite=$(sed -n 's/^Suite: *//p' "$relfile")
                        codename=$(sed -n 's/^Codename: *//p' "$relfile")
                        echo "Detected CD with '$suite' ($codename) distribution"
                        echo "andrew 33333"
                        db_set cdrom/suite "$suite"
                        echo "andrew 44444"
                        db_set cdrom/codename "$codename"

                        break
                fi
        done
}


set_suite_and_codename

echo "andrew2222222222222"
anna-install eject-udeb || true
anna-install apt-cdrom-setup || true

# Install <codename>-support udeb (if available).
db_get cdrom/codename
anna-install $RET-support || true
```

## Add Busybox
* Add Busybox just for more command tools, like awk
* compile busybox and copy to "/", version busybox-1.21.1 for 'awk' use,
    - NOTE: 1.21.1也是ubuntu14.04 initrd.gz中的busybox版本号
* Add compiled busybox to initrd

```
$ cd ~/ubuntu_iso_net_initrd
$ sudo cp ~/busybox-x86_64 ./
```

# 压缩 initrd.gz

* 压缩
```
$ find . | cpio -o -H newc > ../myinitrd.img
$ cd ..
$ gzip -9 myinitrd.img
```
