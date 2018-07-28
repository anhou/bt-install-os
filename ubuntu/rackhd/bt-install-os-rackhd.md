# BT Install Ubuntu by RackHD

* Support Ubuntu 14.04 and 16.04, verified in 14.04

# Installation

## Install OpenTracker in Tracker Server  
* Use opentracker-auto-installer to install opentracker
    - 请参考 Openstacker的安装
    - In the example, it's in RackHD server based on Ubuntu 14.04
* The Tracker Server could be seperated with Seed server(include transferred file and seed file)


## Install Transmission in Seed Server

*  Install Transmission
    -  In the example, it's in RackHD server based on Ubuntu 14.04

```
$ sudo apt-get install transmission-daemon
$ sudo apt-get install transmission-cli
$ transmission-daemon --version
transmission-daemon 2.84 (14307)
```

* Settings

```
$ sudo apt-get install transmission-daemon
$ sudo service transmission-daemon stop
$ sudo vi /etc/transmission-daemon/settings.json
"rpc-whitelist": "127.0.0.1,10.62.*.*,172.31.*.*",
"rpc-whitelist-enabled": false,
"umask": 2,
$ sudo service transmission-daemon start
```

# Preparation in Seed Server

## Prepare Downloaded File
* Copy the transferred file to BT download folder
    - **注意:** 必须先copy 文件到/var/lib/transmission-daemon/downloads/目录下，再添加torrent文件，不然`transmission-remote -n 'transmission:transmission' -l`看到的进度为?,不是100%，可能有其他办法workaround,待研究

```
$ sudo cp ubuntu-14.04.4-server-amd64.iso /var/lib/transmission-daemon/downloads/
```

## Create Seed file for transferred file
* `transmission-create` to make '.torrent' file(transmission could be installed by `apt-get install`)
    - `http://172.31.128.1:6969/announce` is the BT tracker's link

```
$ transmission-create -o ubuntu-14.04.torrent -c "For RackHD" -t http://172.31.128.1:6969/announce ./ubuntu-14.04.4-server-amd64.iso
```

* copy the torrent file to folder that could be accessed by os-installer
    - in this example, it will be got by the modified Ubuntu installer

```
$ sudo cp ubuntu-14.04.torrent /var/renasar/on-http/static/http/
```

* Add torrent in Seed Server

```
$ transmission-remote -n 'transmission:transmission' -a ./ubuntu-14.04.torrent
localhost:9091/transmission/rpc/ responded: "success"

$ transmission-remote -n 'transmission:transmission' -l
ID     Done       Have  ETA           Up    Down  Ratio  Status       Name
   1   100%   607.1 MB  Done         0.0     0.0    0.0  Idle         ubuntu-14.04.4-server-amd64.iso
Sum:          607.1 MB               0.0     0.0
```

# Integrate BT in Ubuntu Installer

* [Integrate BT in Ubuntu Installer in Initrd](./integrate-bt-initrd.md)

# Work in RackHD

* tracker, seed server(包括iso文件，和torrent文件) 准备好了，以及实际工作的initrd.gz也已经准备好了
* 下一步是如何让ipxe/pxe找到initrd.gz再由修改过的initrd.gz去下载torrent,下载iso并执行安装


## Integrate initrd.gz with RackHD

* 在on-http的静态下载文件目录下，创建andrew目录，并copy修改后的initrd.gz文件和其对应的kernel到目录下，供RackHD设置的ipxe启动的时候自动下载调用
    - NOTE: initrd.gz搭配使用的是ubuntu-14.04.4-server-amd64.iso下的 'install'目录的'vmlinuz'不是'install/netboot/ubuntu-installer/amd64/'下的'linux'
        - 因为initrd.gz本身是来在 ubuntu-14.04.4-server-amd64.iso 文件的， 而不是网络安装目录下的image
    - 好像filesystem.squashfs文件由于已经被Ubuntu Installer里的加入的BT功能截断了，并没有运行，如果需要也可以copy过去

```
$ ls install/
filesystem.manifest  filesystem.size  filesystem.squashfs  initrd.gz  mt86plus  netboot  README.sbm  sbm.bin  vmlinuz
$ ls install/netboot/ubuntu-installer/amd64/
boot-screens  initrd.gz  linux  pxelinux.0  pxelinux.cfg
```

```
$ mkdir /var/renasar/on-http/static/http/andrew
$ mv vmlinuz linux      # 如果此处不修改可以在后面的RackHD .ipxe文件中修改morn下载名称
$ sudo cp linux /var/renasar/on-http/static/http/andrew/
$ sudo cp initrd.gz /var/renasar/on-http/static/http/andrew/
$ sudo cp dists/ /var/renasar/on-http/static/http/andrew/ -rf   # 不copy这个可能会影响安装，在安装过程中可能会check这个目录下的文件，待仔细研究
```

## Modify RackHD

* 修改 ubuntu-preseed 让其搭配修改后的initrd.gz 一起工作
    - 以下是在RackHD中的修改
    - 最新RackHD的这部分代码迁移到on-taskgraph了

```
--- /var/renasar/on-http/data/templates/install-ubuntu/ubuntu-preseed-backup    2017-04-19 06:38:42.082791590 +0000
+++ /var/renasar/on-http/data/templates/install-ubuntu/ubuntu-preseed   2017-04-19 09:25:20.962495856 +0000
@@ -29,12 +29,14 @@
 # If you select ftp, the mirror/country string does not need to be set.
 d-i mirror/country string manual
 # Get server:port from repo
-<% var repoHostname = repo.match(/^(https?:\/\/)?([a-zA-Z0-9\.:-]+)/)[2] -%>
-d-i mirror/http/hostname string <%=repoHostname%>
+#<% var repoHostname = repo.match(/^(https?:\/\/)?([a-zA-Z0-9\.:-]+)/)[2] -%>
+#d-i mirror/http/hostname string <%=repoHostname%>
 # Get directory from repo
-<% var repoDirectory = repo.replace(/^(https?:\/\/)?([a-zA-Z0-9\.:-]+)/g,"") -%>
-d-i mirror/http/directory string <%=repoDirectory%>
+#<% var repoDirectory = repo.replace(/^(https?:\/\/)?([a-zA-Z0-9\.:-]+)/g,"") -%>
+#d-i mirror/http/directory string <%=repoDirectory%>
+d-i apt-setup/use_mirror boolean false

 d-i preseed/early_command string \
 <%_ if( typeof progressMilestones !== 'undefined' && progressMilestones.preConfigUri ) { _%>
 wget 'http://<%=server%>:<%=port%><%-progressMilestones.preConfigUri%>' || true; \
```

* 重启on-http service 让改动生效 `sudo service on-http restart`
    - 最新的代码已经挪到on-taskgraph, 需酌情修改

# Discovery node and install OS
* discovery node, set obm
* prepare payload
    - 在RackHD中，repo + baseUrl 会组成 ipxe 下载Ubuntu Installer的kernel (linux) 和initrd的地址
        - 最新代码参考 https://github.com/RackHD/on-taskgraph/blob/master/data/profiles/install-debian.ipxe

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

* ./ubuntu-install.sh 58f6c723370df184045dd3ea Ubuntu andrew
    - 这只是我在实践中简化的脚本，请参考最新的 RackHD 命令

## TODO STUDY

* BT install OS 会去下载额外的东西，但是不会影响iso安装

```
[warning] [2017-04-19T09:33:31.644Z] [on-http] [Services.Configuration] [Server] Configuration value is undefined, using default (arpCacheEnabled => true).
-> /node_modules/on-core/lib/services/configuration.js:73
[debug] [2017-04-19T09:33:31.670Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 26.394 - a2dfb21d-3c10-4912-bec9-b544e4f1b9b5 - /andrew/dists/trusty/InRelease
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.687Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 12.601 - da143a02-f33f-4fe0-a19b-ee0c87d1b3b9 - /andrew/dists/trusty/Release.gpg
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.705Z] [on-http] [Http.Server] [5dd3ea] http: GET 200 13.806 - 86edc4d5-6f41-480e-9469-2032b5526d2e - /andrew/dists/trusty/Release
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.719Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 8.558 - 36ad5d4b-9105-4c2a-ad5d-1c39ff46b5f5 - /andrew/dists/trusty/main/binary-amd64/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.729Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.793 - b0b3c6ec-623e-48e4-9b6b-4b397bdc9e5e - /andrew/dists/trusty/restricted/binary-amd64/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.742Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 10.330 - b007f797-2b3a-4456-974d-25fbdb053879 - /andrew/dists/trusty/universe/binary-amd64/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.751Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.259 - 2712d307-7afb-43d3-adcf-061330511383 - /andrew/dists/trusty/multiverse/binary-amd64/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.761Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.372 - 5461cb95-540c-4259-8cf2-e3ea62fb98ac - /andrew/dists/trusty/main/binary-i386/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.771Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.415 - 5dd6b84e-8a8a-41a1-b479-cb3da3e1abaf - /andrew/dists/trusty/restricted/binary-i386/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.781Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.781 - f21ee211-0ce4-4ea8-930b-4db9c9e4254d - /andrew/dists/trusty/universe/binary-i386/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.793Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 9.307 - 1a00e245-87b4-4f29-93ea-1afb920434c3 - /andrew/dists/trusty/multiverse/binary-i386/Packages.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.802Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.849 - 91957cf7-32ec-447a-a7a9-65cf04f607ce - /andrew/dists/trusty/main/i18n/Translation-en_US.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.813Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 8.591 - c43856cd-b734-4d0c-b678-194de50d4352 - /andrew/dists/trusty/main/i18n/Translation-en.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.821Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.391 - a9b8be8f-f2fe-47c6-90b2-d83506644f9f - /andrew/dists/trusty/multiverse/i18n/Translation-en_US.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.832Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 8.535 - d8a902c2-c50b-466a-a0bf-536f001da84c - /andrew/dists/trusty/multiverse/i18n/Translation-en.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.841Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.669 - f317bbae-300d-4708-9362-1a1454349823 - /andrew/dists/trusty/restricted/i18n/Translation-en_US.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.850Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.911 - 4734246e-d8e9-45aa-8e6f-97b199021887 - /andrew/dists/trusty/restricted/i18n/Translation-en.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.858Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.381 - d552f4c6-e1a4-487c-918e-d8d4e690e41d - /andrew/dists/trusty/universe/i18n/Translation-en_US.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.867Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.615 - 15d97bf3-73a7-47c6-bce3-142a60adb6d4 - /andrew/dists/trusty/universe/i18n/Translation-en.bz2
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.875Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.618 - 406e4133-9e4a-4ea0-83f0-0f8ba2512683 - /andrew/dists/trusty/main/binary-amd64/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.886Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.939 - d6769c0c-3668-48b0-be31-166eeb688d8a - /andrew/dists/trusty/restricted/binary-amd64/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.894Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.957 - b6555ada-eedd-4770-b1bf-739f4209bee0 - /andrew/dists/trusty/universe/binary-amd64/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.904Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.237 - 8e773fca-7743-4919-9285-a14201c99ccf - /andrew/dists/trusty/multiverse/binary-amd64/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.913Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.075 - be42a773-2934-4d6e-ae3e-d541cab85316 - /andrew/dists/trusty/main/binary-i386/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.955Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.070 - 8af785c5-2aca-41ec-bbc1-87b9f7f15faa - /andrew/dists/trusty/restricted/binary-i386/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.963Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.458 - 386812f8-8068-4e4f-bbcc-3dcd13393fcc - /andrew/dists/trusty/universe/binary-i386/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.972Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.502 - ab4c76b1-22b5-41e7-9c44-3196fcf2cf87 - /andrew/dists/trusty/multiverse/binary-i386/Packages.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.981Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.851 - 27dc01c8-1d96-4e26-8e61-d5b62a26124e - /andrew/dists/trusty/main/i18n/Translation-en_US.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.989Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.571 - c39074fc-3b54-4852-971e-6e2b34958acf - /andrew/dists/trusty/main/i18n/Translation-en.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:31.998Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.335 - 9f1100ef-e143-4d90-af5d-a903f54d40a3 - /andrew/dists/trusty/multiverse/i18n/Translation-en_US.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.007Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.147 - dc890f01-348a-4064-a52d-9757471a55e0 - /andrew/dists/trusty/multiverse/i18n/Translation-en.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.015Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.222 - e33cc269-1660-4b30-9878-db1750b344ab - /andrew/dists/trusty/restricted/i18n/Translation-en_US.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.023Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.470 - 753c7cfd-bdb1-49e1-925f-c182fe941f0c - /andrew/dists/trusty/restricted/i18n/Translation-en.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.035Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 10.898 - 2d233083-0071-420f-9b50-1229aa2cfe78 - /andrew/dists/trusty/universe/i18n/Translation-en_US.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.042Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.633 - 51f25385-66f3-4e1a-83d9-5b8aa083b955 - /andrew/dists/trusty/universe/i18n/Translation-en.xz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.051Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.631 - 7b954d95-d3eb-48d2-a439-595c43a867bc - /andrew/dists/trusty/main/binary-amd64/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.059Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.848 - cb3f06cb-226d-42ee-8458-3e5d7ba2e789 - /andrew/dists/trusty/restricted/binary-amd64/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.069Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.488 - 7730c5b3-28c2-4c8d-b4ae-6a8c40d6d7eb - /andrew/dists/trusty/universe/binary-amd64/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.105Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 33.421 - 4ab03a4f-2f95-486b-9f9c-73e039ba36e0 - /andrew/dists/trusty/multiverse/binary-amd64/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.114Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.356 - 65953311-9595-40f5-86c8-6df0aa59884a - /andrew/dists/trusty/main/binary-i386/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.127Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 10.968 - 81dd0aef-d1b0-449b-b3b1-14bc770eb1c6 - /andrew/dists/trusty/restricted/binary-i386/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.136Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.994 - 7ba4ba1d-0c36-4584-a082-e14c5ba9cc86 - /andrew/dists/trusty/universe/binary-i386/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.143Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.302 - 9838e532-802f-458c-b6e1-60f6b3ff734f - /andrew/dists/trusty/multiverse/binary-i386/Packages.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.150Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.350 - 7f306261-0da3-4272-8709-2857be75d3d2 - /andrew/dists/trusty/main/i18n/Translation-en_US.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.157Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.628 - 413b6b3c-7c48-4eff-81e6-6e00fbbfd4a1 - /andrew/dists/trusty/main/i18n/Translation-en.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.165Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.188 - 843859e7-f237-401e-8a26-086290660597 - /andrew/dists/trusty/multiverse/i18n/Translation-en_US.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.174Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.579 - fdc2e9f9-4f67-4a79-958b-8340f08eb671 - /andrew/dists/trusty/multiverse/i18n/Translation-en.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.182Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.921 - 17f82e53-7753-479f-95e0-bf4e1333f6da - /andrew/dists/trusty/restricted/i18n/Translation-en_US.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.226Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.316 - 05dfae61-e79a-48bd-b844-293317e5793b - /andrew/dists/trusty/restricted/i18n/Translation-en.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.260Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.845 - 7673ffda-9514-462d-aa99-a87a56ea0dc1 - /andrew/dists/trusty/universe/i18n/Translation-en_US.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.268Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.146 - a340ed94-2fde-4a98-8516-c1e95b2aa963 - /andrew/dists/trusty/universe/i18n/Translation-en.lzma
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.275Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.282 - 15fbe003-6675-47c9-99d7-3aed93d340d0 - /andrew/dists/trusty/main/binary-amd64/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.287Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.776 - 75d0a5a8-da57-428b-bbe7-5fbea9ce26c4 - /andrew/dists/trusty/restricted/binary-amd64/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.296Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.333 - 4bdeb7de-8287-4e68-af57-9af3a2b86db3 - /andrew/dists/trusty/universe/binary-amd64/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.306Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.564 - 8f8efe72-994b-4710-ba11-fb9232bbec11 - /andrew/dists/trusty/multiverse/binary-amd64/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.326Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 14.889 - 3e055045-e772-4d68-a383-6be488af3e37 - /andrew/dists/trusty/main/binary-i386/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.334Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.644 - 3537d46d-c169-4961-8f02-19df502b6c55 - /andrew/dists/trusty/restricted/binary-i386/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.344Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.432 - 8780c90c-be1a-45d2-8263-a2e116563286 - /andrew/dists/trusty/universe/binary-i386/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.351Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.253 - 4d59b6f8-a305-409d-8788-6a2d7fa53d8e - /andrew/dists/trusty/multiverse/binary-i386/Packages.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.361Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.228 - 8b3a41f1-dd2b-43b4-bc29-1ba03fd09d0c - /andrew/dists/trusty/main/i18n/Translation-en_US.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.377Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.786 - d3826848-b3d1-4b69-b840-f61c433eea81 - /andrew/dists/trusty/main/i18n/Translation-en.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.385Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.839 - 2a60d833-3bc2-4703-a7dd-4fce925bf7da - /andrew/dists/trusty/multiverse/i18n/Translation-en_US.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.395Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.936 - e0017ed2-eec2-44df-a69d-d82d455b2807 - /andrew/dists/trusty/multiverse/i18n/Translation-en.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.436Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 24.911 - a26efb07-623d-4a83-aff5-7083d528fe0e - /andrew/dists/trusty/restricted/i18n/Translation-en_US.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.469Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.899 - f95ddce0-528b-4c6b-b24a-8e06b1aaa053 - /andrew/dists/trusty/restricted/i18n/Translation-en.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.475Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.512 - 45c665ea-261f-4c7c-98f0-b3048fc705a8 - /andrew/dists/trusty/universe/i18n/Translation-en_US.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.485Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.300 - b6e195c6-92d5-4e67-8c46-9392c19379eb - /andrew/dists/trusty/universe/i18n/Translation-en.gz
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.495Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 8.294 - 38781b4d-4d05-4a3b-ae03-0ee727c35095 - /andrew/dists/trusty/main/binary-amd64/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.503Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.796 - 799ee745-ed34-4991-bcc8-6e434beefe21 - /andrew/dists/trusty/restricted/binary-amd64/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.512Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.895 - 05148a57-7d98-4f93-9979-4a64e2088922 - /andrew/dists/trusty/universe/binary-amd64/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.519Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.872 - c3f15850-7c03-4e2f-9b26-81b25303a96f - /andrew/dists/trusty/multiverse/binary-amd64/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.526Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.795 - e8644f98-095f-4a0c-ab6d-6b36184abcfb - /andrew/dists/trusty/main/binary-i386/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.572Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.888 - 95131b5f-d6bf-494c-b25f-6d4bfbacb2ba - /andrew/dists/trusty/restricted/binary-i386/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.580Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.559 - 7c88b0ac-87d8-488b-8bdd-0de0909d6857 - /andrew/dists/trusty/universe/binary-i386/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.589Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.829 - f5885dc0-3706-4eec-ba59-292295059741 - /andrew/dists/trusty/multiverse/binary-i386/Packages
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.598Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.036 - c7bf7d29-2299-46c6-adab-17dc9d4ba3bd - /andrew/dists/trusty/main/i18n/Translation-en_US
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.607Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.958 - 7bb9afdd-66b7-46a5-a86b-7f1b43933043 - /andrew/dists/trusty/main/i18n/Translation-en
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.616Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 6.981 - e52f1fcc-89d7-4dc1-a3d4-571230546a09 - /andrew/dists/trusty/multiverse/i18n/Translation-en_US
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.623Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.370 - 9720ddcd-565e-48ee-bdbb-a7fea458df5e - /andrew/dists/trusty/multiverse/i18n/Translation-en
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.630Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.501 - 8341ab66-cb04-480c-a4bc-5e37f66cdeff - /andrew/dists/trusty/restricted/i18n/Translation-en_US
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.637Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 5.305 - 65e2abe7-3aee-4510-80a0-38f32f8c7773 - /andrew/dists/trusty/restricted/i18n/Translation-en
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.644Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 4.909 - 0afb8e4c-163d-4644-9396-5b6c3ce5adc2 - /andrew/dists/trusty/universe/i18n/Translation-en_US
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
[debug] [2017-04-19T09:33:32.652Z] [on-http] [Http.Server] [5dd3ea] http: GET 404 7.227 - 7e58f0f8-d216-4b6f-8204-36aed22e1388 - /andrew/dists/trusty/universe/i18n/Translation-en
-> /lib/services/http-service.js:368
ipAddress: 172.31.129.3
```

* **TODO** Package.gz在ISO和网络安装中的包的差别以及在安装过程中的影响


## NOTE

1. microkernel woundn't reboot until no donwloading from local host, it's achieved in modified initrd.gz
2. Only OpenSource OS could be supported, currently only Ubuntu
