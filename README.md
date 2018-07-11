# SS/SSR 透明代理脚本
## 脚本简介
ss-tproxy 脚本运行于 Linux 系统，用于实现类似 Windows SS/SSR 客户端的代理功能。目前实现的模式有 global（全局代理模式）、gfwlist（黑名单模式）、chnroute（白名单模式，绕过大陆地址段），考虑到部分用户没有支持 UDP-Relay 的 SS/SSR 节点，所以代理模式又分为 tcp&udp 和 tcponly 两类。Linux 系统下实现透明代理有两种思路：一是利用 iptables 进行重定向（DNAT），二是利用 tun 虚拟网卡进行代理（路由）；因此代理模式又分为 tproxy、tun2socks 两大类，所以一共存在 12 种代理模式（下文中的“本机”指运行 ss-tproxy 的主机）：
- `tproxy_global`：代理 TCP/UDP（本机 UDP 除外），iptables/global 模式
- `tproxy_global_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），iptables/global 模式
- `tproxy_gfwlist`：代理 TCP/UDP（本机 UDP 除外），iptables/gfwlist 模式
- `tproxy_gfwlist_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），iptables/gfwlist 模式
- `tproxy_chnroute`：代理 TCP/UDP（本机 UDP 除外），iptables/chnroute 模式
- `tproxy_chnroute_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），iptables/chnroute 模式
- `tun2socks_global`：代理 TCP/UDP（包括本机 UDP），route/global 模式
- `tun2socks_global_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），route/global 模式
- `tun2socks_gfwlist`：代理 TCP/UDP（包括本机 UDP），route/gfwlist 模式
- `tun2socks_gfwlist_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），route/gfwlist 模式
- `tun2socks_chnroute`：代理 TCP/UDP（包括本机 UDP），route/chnroute 模式
- `tun2socks_chnroute_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），route/chnroute 模式

ss-tproxy 有两种运行环境，一种是在网关/路由上运行，一种是在普通主机上运行。脚本的初衷是将其运行在网关上的（如树莓派），但实际上脚本可以运行在任何网络角色中。本文假设 ss-tproxy 运行在网关上，内网网段为 192.168.1.0/24，网关 IP 为 192.168.1.1。

## 脚本依赖
- [ss-tproxy 脚本相关依赖的安装参考](https://www.zfl9.com/ss-redir.html#%E5%AE%89%E8%A3%85%E4%BE%9D%E8%B5%96)
- `tproxy_global`: ss/ssr-libev, haveged, xt_TPROXY, iproute2, dnsmasq
- `tproxy_gfwlist`: ss/ssr-libev, haveged, xt_TPROXY, iproute2, ipset, perl, dnsmasq
- `tproxy_chnroute`: ss/ssr-libev, haveged, xt_TPROXY, iproute2, ipset, chinadns, dnsmasq
- `tproxy_global_tcp`: ss/ssr-libev, haveged, dnsforwarder
- `tproxy_gfwlist_tcp`: ss/ssr-libev, haveged, ipset, perl, dnsmasq, dnsforwarder
- `tproxy_chnroute_tcp`: ss/ssr-libev, haveged, ipset, chinadns, dnsforwarder
- `tun2socks_global`: ss/ssr(版本不限), haveged, tun2socks, iproute2, dnsmasq
- `tun2socks_gfwlist`: ss/ssr(版本不限), haveged, tun2socks, iproute2, ipset, perl, dnsmasq
- `tun2socks_chnroute`: ss/ssr(版本不限), haveged, tun2socks, iproute2, ipset, chinadns, dnsmasq
- `tun2socks_global_tcp`: ss/ssr(版本不限), haveged, tun2socks, iproute2, dnsforwarder
- `tun2socks_gfwlist_tcp`: ss/ssr(版本不限), haveged, tun2socks, iproute2, ipset, perl, dnsmasq, dnsforwarder
- `tun2socks_chnroute_tcp`: ss/ssr(版本不限), haveged, tun2socks, iproute2, ipset, chinadns, dnsforwarder
- haveged 依赖项是可选的，主要用于防止系统的熵过低，从而导致 ss-redir、ss-tunnel、ss-local 启动失败等问题
- `*gfwlist*` 模式更新列表时依赖 curl、base64；`*chnroute*` 模式更新列表时依赖 curl；建议都安装（反正迟早要装）
- `*gfwlist*` 模式中的 perl 其实可以使用 sed 替代，但由于更新 gfwlist 列表依赖 perl5 v5.10.0+，所以直接使用了 perl

## 端口占用
- 请确保相关端口未被其它进程占用，如果有请自行解决
- `tproxy_global`: ss-redir=60080, ss-tunnel=60053, dnsmasq=53
- `tproxy_gfwlist`: ss-redir=60080, ss-tunnel=60053, dnsmasq=53
- `tproxy_chnroute`: ss-redir=60080, ss-tunnel=60053, chinadns=65353, dnsmasq=53
- `tproxy_global_tcp`: ss-redir=60080, dnsforwarder=53
- `tproxy_gfwlist_tcp`: ss-redir=60080, dnsforwarder=60053, dnsmasq=53
- `tproxy_chnroute_tcp`: ss-redir=60080, dnsforwarder=60053, chinadns=65353, dnsforwarder=53
- `tun2socks_global`: dnsmasq=53
- `tun2socks_gfwlist`: dnsmasq=53
- `tun2socks_chnroute`: chinadns=60053, dnsmasq=53
- `tun2socks_global_tcp`: dnsforwarder=53
- `tun2socks_gfwlist_tcp`: dnsforwarder=60053, dnsmasq=53
- `tun2socks_chnroute_tcp`: dnsforwarder=60053, chinadns=65353, dnsforwarder=53

## 脚本用法
**获取**
- `git clone https://github.com/zfl9/ss-tproxy.git --single-branch`

**安装**
- `cd ss-tproxy`
- `cp -af ss-tproxy /usr/local/bin`
- `chmod 0755 /usr/local/bin/ss-tproxy`
- `chown root:root /usr/local/bin/ss-tproxy`
- `mkdir -m 0755 -p /etc/tproxy`
- `cp -af ss-tproxy.conf gfwlist.txt chnroute.* /etc/tproxy`
- `chmod 0644 /etc/tproxy/* && chown -R root:root /etc/tproxy`

**配置**
- 脚本的配置文件为 `/etc/tproxy/ss-tproxy.conf`，修改后重启脚本才能生效
- 默认模式为 `tproxy_chnroute`，这也是 v1 版本中的模式，根据自己的需要更改
- 如果使用 `tproxy*` 模式，则修改 `ss/ssr 配置` 段中的相关 SS/SSR 服务器信息
- 如果使用 `tun2socks*` 模式，则修改 `socks5 配置` 段中的相关 socks5 代理信息
- `dns_remote` 用于指定代理状态下的 DNS，默认为 8.8.8.8:53，根据自己的需要修改
- `dns_direct` 用于指定直连状态下的 DNS，默认为 114、119 DNS，根据自己的需要修改
- `iptables_intranet` 用于指定要代理的内网网段，默认为 192.168.0.0/16，根据需要修改

**自启**（Systemd）
- `cp -af ss-tproxy.service /etc/systemd/system`
- `systemctl daemon-reload`
- `systemctl enable ss-tproxy.service`

**自启**（SysVinit）
- `touch /etc/rc.d/rc.local`
- `chmod +x /etc/rc.d/rc.local`
- `echo '/usr/local/bin/ss-tproxy start' >>/etc/rc.d/rc.local`

配置 ss-tproxy 开机自启后容易出现一个问题，那就是必须再次运行 `ss-tproxy restart` 后才能正常代理（这之前查看运行状态可能看不出任何问题，因为都是 running 状态），这是因为 ss-tproxy 启动过早了，且 server_addr/socks5_remote 为 hostname 形式，且没有将 server_addr/socks5_remote 中的 hostname 加入 /etc/hosts 文件而导致的。因为 ss-tproxy 启动时，网络还没准备好，此时根本无法解析这个 hostname。要避免这个问题，可以采取一个非常简单的方法，那就是将 hostname 加入到 /etc/hosts 中，如 hostname 为 node.proxy.net，对应的 IP 为 11.22.33.44，则只需执行 `echo "11.22.33.44 node.proxy.net" >>/etc/hosts`。不过得注意个问题，那就是假如这个 IP 变了，别忘了修改 /etc/hosts 文件哦。命令行获取某个域名对应的 IP 地址的方法：`dig +short HOSTNAME`。如果你使用的是 ArchLinux 发行版，也可以利用 netctl 的 hook 钩子脚本来启动 ss-tproxy（比如拨号成功后启动 ss-tproxy），具体配置可参考 [Arch 官方文档](https://wiki.archlinux.org/index.php/netctl#Using_hooks)。

// TODO
