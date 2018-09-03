# SS/SSR/Socks5 全局代理
## 脚本简介
ss-tproxy 脚本运行于 Linux 系统，用于实现类似 Windows SS/SSR 客户端的代理功能，当然也支持 Socks5 协议的全局代理配置（如 SSH 代理隧道）。目前实现的模式有 global（全局代理模式）、gfwlist（黑名单模式）、chnroute（白名单模式，绕过大陆地址段）、chnonly（仅代理大陆域名，国外翻回国内专用），考虑到部分用户没有支持 UDP-Relay 的 SS/SSR 节点，所以代理模式又分为 tcp&udp 和 tcponly 两类。Linux 系统下实现透明代理有两种思路：一是利用 iptables 进行重定向（DNAT），二是利用 tun 虚拟网卡进行代理（路由）；因此代理模式又分为 tproxy、tun2socks 两大类，所以一共存在 12 种代理模式（下文中的“本机”指运行 ss-tproxy 的主机）：
- `tproxy_global`：代理 TCP/UDP（本机 UDP 除外），iptables/global 模式
- `tproxy_global_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），iptables/global 模式
- `tproxy_gfwlist`：代理 TCP/UDP（本机 UDP 除外），iptables/gfwlist 模式
- `tproxy_gfwlist_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），iptables/gfwlist 模式
- `tproxy_chnroute`：代理 TCP/UDP（本机 UDP 除外），iptables/chnroute 模式
- `tproxy_chnroute_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），iptables/chnroute 模式
- `tun2socks_global`：代理 TCP/UDP（包括本机 UDP），tun2socks/global 模式
- `tun2socks_global_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），tun2socks/global 模式
- `tun2socks_gfwlist`：代理 TCP/UDP（包括本机 UDP），tun2socks/gfwlist 模式
- `tun2socks_gfwlist_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），tun2socks/gfwlist 模式
- `tun2socks_chnroute`：代理 TCP/UDP（包括本机 UDP），tun2socks/chnroute 模式
- `tun2socks_chnroute_tcp`：仅代理 TCP（DNS 使用 TCP 方式查询），tun2socks/chnroute 模式

> 注：chnonly 模式和 gfwlist 模式本质上没有区别，如需使用 chnonly 请选择 `*gfwlist*` mode。

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
- `*gfwlist*` 模式更新列表时依赖 curl、base64；`*chnroute*` 模式更新列表时依赖 curl；建议安装，以备不时之需
- `*gfwlist*` 模式中的 perl 其实可以使用 sed 替代，但由于更新 gfwlist 列表依赖 perl5 v5.10.0+，所以直接用了 perl

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
**安装**
- `git clone https://github.com/zfl9/ss-tproxy.git`
- `cd ss-tproxy`
- `cp -af ss-tproxy /usr/local/bin`
- `chmod 0755 /usr/local/bin/ss-tproxy`
- `chown root:root /usr/local/bin/ss-tproxy`
- `mkdir -m 0755 -p /etc/tproxy`
- `cp -af ss-tproxy.conf gfwlist.* chnroute.* /etc/tproxy`
- `chmod 0644 /etc/tproxy/* && chown -R root:root /etc/tproxy`

**卸载**
- `ss-tproxy stop`
- `rm -fr /etc/tproxy /usr/local/bin/ss-tproxy`

**简介**
- `ss-tproxy`：脚本文件
- `ss-tproxy.conf`：配置文件
- `ss-tproxy.service`：服务文件
- `gfwlist.txt`：gfwlist 域名文件，不可配置
- `gfwlist.ext`：gfwlsit 黑名单文件，可配置
- `chnroute.set`：chnroute for ipset，不可配置
- `chnroute.txt`：chnroute for chinadns，不可配置

**配置**
- 脚本的配置文件为 `/etc/tproxy/ss-tproxy.conf`，修改后重启脚本才能生效
- 默认模式为 `tproxy_chnroute`，这也是 v1 版本中的模式，根据你的需要更改
- 如果使用 `tproxy*` 模式，则修改 `ss/ssr 配置` 段中的相关 SS/SSR 服务器信息
- 如果使用 `tun2socks*` 模式，则修改 `socks5 配置` 段中的相关 socks5 代理信息
- `dns_remote` 为远程 DNS 服务器（走代理），默认为 Google DNS，根据需要修改
- `dns_direct` 为直连 DNS 服务器（走直连），默认为 114 公共DNS，根据需要修改
- `iptables_intranet` 指定要代理的内网网段，默认为 192.168.0.0/16，根据需要修改
- 如需配置 gfwlist 黑名单，请编辑 `/etc/tproxy/gfwlist.ext`，修改后需重启脚本生效

如果你需要使用 chnonly 模式（国外翻进国内），请选择 `*gfwlist*` 代理模式，比如 `tproxy_gfwlist`。chnonly 模式下，你必须修改 ss-tproxy.conf 中的 `dns_remote` 为国内的 DNS，如 `dns_remote='114.114.114.114:53'`，并将 `dns_direct` 改为本地 DNS（国外的），如 `dns_direct='8.8.8.8'`；因为 chnonly 模式与 gfwlist 模式共享 gfwlist.txt、gfwlist.ext 文件，所以在第一次使用时你必须先运行 `ss-tproxy update-chnonly` 将默认的 gfwlist.txt 内容替换为大陆域名（更新列表时，也应使用 `ss-tproxy update-chnonly`），并且注释掉 gfwlist.ext 中的 Telegram IP 段，因为这是为正常翻墙设置的。

**自启**（Systemd）
- `mv -f ss-tproxy.service /etc/systemd/system`
- `systemctl daemon-reload`
- `systemctl enable ss-tproxy.service`

**自启**（SysVinit）
- `touch /etc/rc.d/rc.local`
- `chmod +x /etc/rc.d/rc.local`
- `echo '/usr/local/bin/ss-tproxy start' >>/etc/rc.d/rc.local`

如果 ss-tproxy 主机使用 PPPoE 拨号上网（或其它耗时比较长的方式），那么配置自启后，可能导致 ss-tproxy 在网络还未完全准备好的情况下先运行。此时如果 ss-tproxy.conf 中的 socks5_remote、server_addr 为域名形式，那么就会导致 ss-tproxy 启动失败（甚至会卡一段时间，因为它一直在尝试解析这些域名，直到超时为止）。要恢复正常的代理，只能在启动完成后手动进行 `ss-tproxy restart`。如果你想避免这种 bug 的发生，请尽量将 ss-tproxy.conf 中的 socks5_remote、server_addr 替换为 IP 地址形式，或者将这些域名添加到 ss-tproxy 主机的 /etc/hosts 文件，如果你和我一样使用的 ArchLinux，那么最好的解决方式就是利用 netctl 的 hook 启动 ss-tproxy（如拨号成功后再启动 ss-tproxy），具体配置可参考 [Arch 官方文档](https://wiki.archlinux.org/index.php/netctl#Using_hooks)。

**用法**
- `ss-tproxy help`：查看帮助
- `ss-tproxy start`：启动代理
- `ss-tproxy stop`：关闭代理
- `ss-tproxy restart`：重启代理
- `ss-tproxy status`：代理状态
- `ss-tproxy check-depend`：检查依赖
- `ss-tproxy flush-cache`：清空 DNS 缓存
- `ss-tproxy flush-gfwlist`：清空 ipset-gfwlist IP 列表
- `ss-tproxy update-chnonly`：更新 chnonly（restart 生效）
- `ss-tproxy update-gfwlist`：更新 gfwlist（restart 生效）
- `ss-tproxy update-chnroute`：更新 chnroute（restart 生效）

`ss-tproxy flush-gfwlist` 的作用：因为 `*gfwlist*` 模式下 `ss-tproxy restart`、`ss-tproxy stop; ss-tproxy start` 不会清空 `ipset-gfwlist` 集合，如果你进行了 `ss-tproxy update-gfwlist`、`ss-tproxy update-chnonly` 操作，或修改了 `/etc/tproxy/gfwlist.ext` 文件，建议在 start 前执行一下此步骤，防止因为之前遗留的 ipset-gfwlist 列表导致各种稀奇古怪的问题。注意，如果执行了 `ss-tproxy flush-gfwlist` 那么你可能需要清空内网主机的 dns 缓存，并且重启浏览器等需要代理的应用。

**日志**
> 脚本默认关闭了日志输出，如果需要，请修改 ss-tproxy.conf，打开相应的 log/verbose 选项

- ss-redir：`/var/log/ss-redir.log`
- ss-tunnel：`/var/log/ss-tunnel.log`
- tun2socks：`/var/log/tun2socks.log`
- dnsmasq：`/var/log/dnsmasq.log`
- chinadns：`/var/log/chinadns.log`
- dnsforwarder：`/var/log/dnsforwarder.log`

## 更多信息
- [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)
- [chinadns](https://github.com/shadowsocks/ChinaDNS)
- [dnsforwarder](https://github.com/holmium/dnsforwarder)
- [gotun2socks](https://github.com/yinghuocho/gotun2socks)
- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
- [shadowsocksr-libev](https://github.com/shadowsocksr-backup/shadowsocksr-libev)
- [gfwlist2dnsmasq](https://github.com/zfl9/gfwlist2dnsmasq)
- [ss-redir 透明代理](https://www.zfl9.com/ss-redir.html)
