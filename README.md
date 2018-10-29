# Linux TCP+UDP 透明代理
## 脚本简介
ss-tproxy 目前存在 3 个版本，分别为 v1、v2、v3。最初编写 ss-tproxy 脚本的目的很简单，就是为了透明代理 ss/ssr，这也是脚本名称的由来。在 v1 版本中，ss-tproxy 只实现了 chnroute 大陆地址分流模式，因为我这边的网络即使访问普通的国外网站也很慢，所以干脆将国外网站都走代理。随着 ss-tproxy 被 star 的数量越来越多，促使我编写了 v2 版本，v2 版本先后实现了 global、gfwlist、chnonly、chnroute 四种分流模式，并且合并了 [ss-tun2socks](https://github.com/zfl9/ss-tun2socks)，支持 ss/ssr/v2ray/socks5 的透明代理。因脚本结构问题，导致 v2 版本的代码行数达到了 1300+，使得脚本过于臃肿且难以维护，最终催生了现在的 v3 版本。

ss-tproxy v3 基本上可以认为是 ss-tproxy v2 的精简优化版，v3 版本去掉了很多不是那么常用的代理模式，如 tun2socks、tcponly，并提取出了 ss/ssr/v2ray 等代理软件的相同规则，所以 v3 版本目前只有两大代理模式：REDIRECT + TPROXY、TPROXY + TPROXY（纯 TPROXY 方式）。REDIRECT + TPROXY 是指 TCP 使用 REDIRECT 方式代理而 UDP 使用 TPROXY 方式代理；纯 TPROXY 方式则是指 TCP 和 UDP 均使用 TPROXY 方式代理。目前来说，ss-libev、ssr-libev、v2ray-core、redsocks2 均为 REDIRECT + TPROXY 组合方式，而最新版 v2ray-core 则支持纯 TPROXY 方式的代理。在 v3 中，究竟使用哪种组合是由 `proxy_tproxy='boolean_value'` 决定的，如果为 true 则为纯 TPROXY 模式，否则为 REDIRECT + TPROXY 模式（默认）。

v3 版本仍然实现了 global、gfwlist、chnonly、chnroute 四种分流模式；global 是指全部流量都走代理；gfwlist 是指 gfwlist.txt 与 gfwlist.ext 列表中的地址走代理，其余走直连；chnonly 本质与 gfwlist 没区别，只是 gfwlist.txt 与 gfwlist.ext 列表中的域名为大陆域名，所以 chnonly 是国外翻回国内的专用模式；chnroute 则是从 v1 版本开始就有的模式，chnroute 模式会放行特殊地址、国内地址的流量，然后其它的流量（发往国外的流量）都会走代理出去（默认）。

如果你需要使用 tun2socks 模式（socks5 透明代理）、tcponly 模式（仅代理 TCP 流量），请转到 [ss-tproxy v2 版本](https://github.com/zfl9/ss-tproxy/tree/v2-master)。关于 tcponly 模式，可能以后会在 v3 版本中加上，但目前暂时不考虑。而对于 socks5 透明代理，我不是很建议使用 tun2socks，因为 tun2socks 是 golang 写的一个程序，在树莓派上性能堪忧（v2ray 也是如此），即使你认为性能可以接受，我还是建议你使用 [redsocks2](https://github.com/semigodking/redsocks) 来配合 v3 脚本的 REDIRECT + TPROXY 模式（当然如果你的 socks5 代理仅支持 TCP，那么目前还是只能用 v2 的 tun2socks 模式，直到 v3 的 tcponly 模式上线）。使用 redsocks2 配合 REDIRECT + TPROXY 模式很简单，配置好 redsocks2 之后，在 ss-tproxy.conf 的 runcmd 中填写 redsocks2 的启动命令就行。

ss-tproxy 可以运行在 Linux 软路由/网关、Linux 物理机、Linux 虚拟机等环境中，可以透明代理 ss-tproxy 主机本身以及所有网关指向 ss-tproxy 主机的其它主机的 TCP 与 UDP 流量。透明代理主机本身的 TCP 和 UDP 没什么好讲的，我主要说一下透明代理"其它主机"的 TCP 和 UDP 的流量。即使 ss-tproxy 不是运行在 Linux 软路由/网关上，但通过某些"技巧"，ss-tproxy 依旧能够透明代理其它主机的 TCP 与 UDP 流量。比如你在某台内网主机（假设 IP 地址为 192.168.0.100）中运行 ss-tproxy，那么你只要将该内网中的其它主机的网关以及 DNS 服务器设为 192.168.0.100，那么这些内网主机的 TCP 和 UDP 就会被透明代理。当然这台内网主机可以是一个 Linux 虚拟机（网络要设为桥接模式，通常只需一张网卡），假设这台虚拟机的 IP 为 192.168.0.200，虚拟机能够与内网中的其它主机正常通信，也能够正常上外网，那么你只需将内网中的其它主机的网关和 DNS 设为 192.168.0.200 就可以透明代理它们的 TCP 与 UDP 流量。

## 脚本依赖
- global 模式：iproute2、TPROXY、dnsmasq
- gfwlist 模式：iproute2、TPROXY、dnsmasq、perl、ipset
- chnroute 模式：iproute2、TPROXY、dnsmasq、chinadns、ipset

## 端口占用
- global 模式：dnsmasq:53@tcp+udp
- gfwlist 模式：dnsmasq:53@tcp+udp
- chnroute 模式：dnsmasq:53@tcp+udp、chinadns:65353@udp

## 脚本用法
**安装**
```bash
git clone https://github.com/zfl9/ss-tproxy
cd ss-tproxy
cp -af ss-tproxy /usr/local/bin
chmod 0755 /usr/local/bin/ss-tproxy
chown root:root /usr/local/bin/ss-tproxy
mkdir -m 0755 -p /etc/ss-tproxy
cp -af ss-tproxy.conf gfwlist.* chnroute.* /etc/ss-tproxy
chmod 0644 /etc/ss-tproxy/* && chown -R root:root /etc/ss-tproxy
```

**删除**
```bash
ss-tproxy stop
ss-tproxy flush-iptables
rm -fr /etc/ss-tproxy /usr/local/bin/ss-tproxy
```

**简介**
- `ss-tproxy`：脚本文件
- `ss-tproxy.conf`：配置文件
- `ss-tproxy.service`：服务文件
- `gfwlist.txt`：gfwlist 域名文件，不可配置
- `gfwlist.ext`：gfwlsit 黑名单文件，可配置
- `chnroute.set`：chnroute for ipset，不可配置
- `chnroute.txt`：chnroute for chinadns，不可配置

**配置**
- 脚本配置文件为 `/etc/ss-tproxy/ss-tproxy.conf`，修改后重启脚本才能生效
- 默认分流模式为 `chnroute`，这也是 v1 版本中的分流模式，根据你的需要修改
- 根据实际情况，修改 `proxy` 配置段中的代理软件的信息，详细内容见下面的说明
- `dns_remote` 为远程 DNS 服务器（走代理），默认为 Google DNS，根据需要修改
- `dns_direct` 为直连 DNS 服务器（走直连），默认为 114 公共DNS，根据需要修改
- `iptables_intranet` 为要代理的内网的网段，默认为 192.168.0.0/16，根据需要修改
- 如需配置 gfwlist 扩展列表，请编辑 `/etc/ss-tproxy/gfwlist.ext`，修改后重启脚本生效

// TODO
