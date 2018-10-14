# SS/SSR/V2Ray/Socks5 透明代理
## 脚本简介
ss-tproxy 脚本运行于 Linux 系统（网关、软路由、虚拟机、普通 PC），用于实现 SS/SSR/V2Ray/Socks5 全局透明代理功能。普遍用法是将 ss-tproxy 部署在 Linux 软路由（或位于桥接模式下的 Linux 虚拟机），透明代理内网主机的 TCP、UDP 数据流（具体玩法可参考 [ss-tproxy 常见问题](https://www.zfl9.com/ss-redir.html#%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98)）。脚本目前实现了 4 种分流模式：global（全局模式，不分流）、gfwlist（仅代理 gfwlist 域名）、chnonly（仅代理大陆域名，国外翻回国内）、chnroute（绕过大陆地址段，其余均走代理）。脚本目前定义了 18 种代理模式，如下（下文中的“本机”指运行 ss-tproxy 的主机）：
```bash
mode='v2ray_global'            # v2ray  global   模式
mode='v2ray_gfwlist'           # v2ray  gfwlist  模式
mode='v2ray_chnroute'          # v2ray  chnroute 模式
mode='tlspxy_global'           # tlspxy global   模式
mode='tlspxy_gfwlist'          # tlspxy gfwlist  模式
mode='tlspxy_chnroute'         # tlspxy chnroute 模式
mode='tproxy_global'           # ss/ssr global   模式
mode='tproxy_gfwlist'          # ss/ssr gfwlist  模式
mode='tproxy_chnroute'         # ss/ssr chnroute 模式
mode='tproxy_global_tcp'       # ss/ssr global   模式 (tcponly)
mode='tproxy_gfwlist_tcp'      # ss/ssr gfwlist  模式 (tcponly)
mode='tproxy_chnroute_tcp'     # ss/ssr chnroute 模式 (tcponly)
mode='tun2socks_global'        # socks5 global   模式
mode='tun2socks_gfwlist'       # socks5 gfwlist  模式
mode='tun2socks_chnroute'      # socks5 chnroute 模式
mode='tun2socks_global_tcp'    # socks5 global   模式 (tcponly)
mode='tun2socks_gfwlist_tcp'   # socks5 gfwlist  模式 (tcponly)
mode='tun2socks_chnroute_tcp'  # socks5 chnroute 模式 (tcponly)
```
标识了 `tcponly` 的 mode 表示只代理 tcp 流量（dns 通过 tcp 方式解析），udp 不会被处理，主要用于不支持 udp relay 的 ss/ssr/socks5 代理。除了 `tun2socks` 和 `tlspxy` mode 外，其它 mode 均不会代理 ss-tproxy 本机的 udp 流量（dns 会另外处理，见下面的说明）。另外，`chnonly` 模式并未单独分出来，因为它本质上与 `gfwlist` 模式相同，只不过域名列表不一样而已，所以如果要使用 `chnonly` 分流模式，请选择对应的 `gfwlist` mode（当然还需要几个步骤，后面会说明）。

为什么除了 `tun2socks` 和 `tlspxy` mode 外（tlspxy 即 [tls-proxy](https://github.com/zfl9/tls-proxy)，是我自己写的一个代理工具），其他 mode 都不代理本机的 udp 流量呢？这里面其实是有历史原因的，怎么说呢？因为在我自己写 tls-proxy 之前，我一直以为本机的 udp 是无法通过 TPROXY 方式代理的，当初的理由很简单，因为当我尝试在 OUTPUT 链添加 TPROXY target 时，会提示这个错误：`x_tables: ip_tables: TPROXY target: used from hooks OUTPUT, but only usable from PREROUTING`（意思是 TPROXY 只能用于 PREROUTING 链），只能用于 PREROUTING 链的话，不就只能代理来自"内网"的流量了吗？当时也是因为这个原因，我才弄了个 tun2socks 模式，那为什么 tun2socks 模式就能代理本机 UDP？因为 tun2socks 会创建一张 tun 虚拟网卡，只要我们将要代理的流量通过 iproute2 策略路由，送入这张 tun 虚拟网卡就行，也就是和 VPN 差不多。

直到前段时间，我因为 v2ray 对 QUIC 的支持问题而不爽，决定自己写一个 C 语言版的 v2ray（当然我只实现了 v2ray 的 websocket + tls + web 方案，毕竟这是所谓的最安全方案），经过自己的不断努力，终于写了个成品出来，也就是上面提到的 `tls-proxy`，编写 tls-proxy 期间，我也对 TPROXY 透明代理的原理有了更多深刻的理解，才知道原来 TPROXY 是可以代理本机 TCP、UDP 流量的，虽然 iptables 不允许我们直接在 OUTPUT 链上设置 TPROXY target，但是我们可以在 OUTPUT 链上打上 fwmark，然后在经过 iproute2 策略路由时，将打了指定 fwmark 的数据路由到本机（从 loopback 网卡进去），正是因为这个从 loopback 网卡流入的步骤，允许我们在 PREROUTING 链（数据包流入某张网卡之后，首先被 PREROUTING 链处理，然后再进行路由）上设置相应的 TPROXY target，然后我们就可以代理本机的 TCP 和 UDP 了。

同理，其它支持 UDP Relay（TPROXY 方式）的 mode 都可以这么做。你现在又要问了，那为什么现在还是只有 `tlspxy` 和 `tun2socks` mode 才代理本机 UDP 呢？原因很简单，因为我最近真的没时间，等有时间折腾的时候，我就会更新 v3 版本的 ss-tproxy，将这些功能加上去，并且将无关紧要的 mode 去掉，比如 tun2socks，因为 tun2socks 模式已经没有任何优势了。

另外，v2ray 最新版也支持纯 TPROXY 方式的代理了（TCP 和 UDP 都使用 TPROXY，以前 TCP 是使用 REDIRECT），也就是和 tls-proxy 一样了，所以，如果你愿意，你也可以在 `tlspxy_*` mode 上使用这种配置的 v2ray。

## 脚本依赖
- [ss-tproxy 脚本相关依赖的安装参考](https://www.zfl9.com/ss-redir.html#%E5%AE%89%E8%A3%85%E4%BE%9D%E8%B5%96)
- `v2ray_global`: v2ray-core, xt_TPROXY, iproute2, dnsmasq
- `v2ray_gfwlist`: v2ray-core, xt_TPROXY, iproute2, ipset, perl, dnsmasq
- `v2ray_chnroute`: v2ray-core, xt_TPROXY, iproute2, ipset, chinadns, dnsmasq
- `tlspxy_global`: tls-proxy, xt_TPROXY, iproute2, dnsmasq
- `tlspxy_gfwlist`: tls-proxy, xt_TPROXY, iproute2, ipset, perl, dnsmasq
- `tlspxy_chnroute`: tls-proxy, xt_TPROXY, iproute2, ipset, chinadns, dnsmasq
- `tproxy_global`: ss/ssr-libev, haveged, xt_TPROXY, iproute2, dnsmasq
- `tproxy_gfwlist`: ss/ssr-libev, haveged, xt_TPROXY, iproute2, ipset, perl, dnsmasq
- `tproxy_chnroute`: ss/ssr-libev, haveged, xt_TPROXY, iproute2, ipset, chinadns, dnsmasq
- `tproxy_global_tcp`: ss/ssr-libev, haveged, dnsforwarder
- `tproxy_gfwlist_tcp`: ss/ssr-libev, haveged, ipset, perl, dnsmasq, dnsforwarder
- `tproxy_chnroute_tcp`: ss/ssr-libev, haveged, ipset, chinadns, dnsforwarder
- `tun2socks_global`: socks5 代理, tun2socks, iproute2, dnsmasq
- `tun2socks_gfwlist`: socks5 代理, tun2socks, iproute2, ipset, perl, dnsmasq
- `tun2socks_chnroute`: socks5 代理, tun2socks, iproute2, ipset, chinadns, dnsmasq
- `tun2socks_global_tcp`: socks5 代理, tun2socks, iproute2, dnsforwarder
- `tun2socks_gfwlist_tcp`: socks5 代理, tun2socks, iproute2, ipset, perl, dnsmasq, dnsforwarder
- `tun2socks_chnroute_tcp`: socks5 代理, tun2socks, iproute2, ipset, chinadns, dnsforwarder
- haveged 依赖项是可选的，主要用于防止系统的熵过低，从而导致 ss-redir、ss-tunnel、ss-local 启动失败等问题
- `*gfwlist*` 模式更新列表时依赖 curl、base64；`*chnroute*` 模式更新列表时依赖 curl；建议安装，以备不时之需
- `*gfwlist*` 模式中的 perl 其实可以使用 sed 替代，但由于更新 gfwlist 列表依赖 perl5 v5.10.0+，所以直接用了 perl
- tun2socks 依赖 `net-tools` 包中的 `ifconfig` 命令，如果启动 tun2socks 失败，可能是没有安装 `net-tools` 的原因

## 端口占用
- 请确保相关端口未被其它进程占用，如果有请自行解决
- `v2ray_global`: dnsmasq=53/udp
- `v2ray_gfwlist`: dnsmasq=53/udp
- `v2ray_chnroute`: chinadns=65353/udp, dnsmasq=53/udp
- `tlspxy_global`: dnsmasq=60053/udp
- `tlspxy_gfwlist`: dnsmasq=60053/udp
- `tlspxy_chnroute`: chinadns=65353/udp, dnsmasq=60053/udp
- `tproxy_global`: ss-redir=60080/tcp+udp, ss-tunnel=60053/udp, dnsmasq=53/udp
- `tproxy_gfwlist`: ss-redir=60080/tcp+udp, ss-tunnel=60053/udp, dnsmasq=53/udp
- `tproxy_chnroute`: ss-redir=60080/tcp+udp, ss-tunnel=60053/udp, chinadns=65353/udp, dnsmasq=53/udp
- `tproxy_global_tcp`: ss-redir=60080/tcp, dnsforwarder=53/udp
- `tproxy_gfwlist_tcp`: ss-redir=60080/tcp, dnsforwarder=60053/udp, dnsmasq=53/udp
- `tproxy_chnroute_tcp`: ss-redir=60080/tcp, dnsforwarder=60053/udp, chinadns=65353/udp, dnsforwarder=53/udp
- `tun2socks_global`: dnsmasq=53/udp
- `tun2socks_gfwlist`: dnsmasq=53/udp
- `tun2socks_chnroute`: chinadns=60053/udp, dnsmasq=53/udp
- `tun2socks_global_tcp`: dnsforwarder=53/udp
- `tun2socks_gfwlist_tcp`: dnsforwarder=60053/udp, dnsmasq=53/udp
- `tun2socks_chnroute_tcp`: dnsforwarder=60053/udp, chinadns=65353/udp, dnsforwarder=53/udp

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
- 如果使用 `v2ray*` 模式，则修改 `v2ray 配置` 段中的相关 V2Ray 客户端的信息
- 如果使用 `tlspxy*` 模式，则修改 `tlspxy 配置` 段中的相关 tlspxy 客户端信息
- 如果使用 `tproxy*` 模式，则修改 `ss/ssr 配置` 段中的相关 SS/SSR 服务器信息
- 如果使用 `tun2socks*` 模式，则修改 `socks5 配置` 段中的相关 socks5 代理信息
- `dns_remote` 为远程 DNS 服务器（走代理），默认为 Google DNS，根据需要修改
- `dns_direct` 为直连 DNS 服务器（走直连），默认为 114 公共DNS，根据需要修改
- `iptables_intranet` 指定要代理的内网网段，默认为 192.168.0.0/16，根据需要修改
- 如需配置 gfwlist 黑名单，请编辑 `/etc/tproxy/gfwlist.ext`，修改后需重启脚本生效

如果你需要使用 chnonly 模式（国外翻进国内），请选择 `*gfwlist*` 代理模式，比如 `tproxy_gfwlist`。chnonly 模式下，你必须修改 ss-tproxy.conf 中的 `dns_remote` 为国内的 DNS，如 `dns_remote='114.114.114.114:53'`，并将 `dns_direct` 改为本地 DNS（国外的），如 `dns_direct='8.8.8.8'`；因为 chnonly 模式与 gfwlist 模式共享 gfwlist.txt、gfwlist.ext 文件，所以在第一次使用时你必须先运行 `ss-tproxy update-chnonly` 将默认的 gfwlist.txt 内容替换为大陆域名（更新列表时，也应使用 `ss-tproxy update-chnonly`），并且注释掉 gfwlist.ext 中的 Telegram IP 段，因为这是为正常翻墙设置的，反之亦然。

如果使用 v2ray 模式，你必须配置 v2ray 客户端的 `dokodemo-door` 传入协议，并且需要两个 `dokodemo-door` 配置，一个用于实现类似 ss-redir 的透明代理，另一个用于实现类似 ss-tunnel 的端口转发（解析 DNS）。具体配置可参考（原有的 inbound 可以不动，通常该 inbound 是一个 socks5 传入协议，你只要保证不同的 inbound 的监听端口不冲突就行）：
```javascript
{
    "inbound": { ... },
    "inboundDetour": [
        // as ss-redir
        {
            "port": 60080,
            "protocol": "dokodemo-door",
            "settings": {
                "network": "tcp,udp",
                "followRedirect": true,
                "domainOverride": ["quic"]
            }
        },
        // as ss-tunnel
        {
            "port": 60053,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "8.8.8.8",
                "port": 53,
                "network": "udp",
                "followRedirect": false
            }
        },
        ...
    ],
    "outbound": { ... },
    "outboundDetour": [ ... ],
    "routing": { ... }
}
```

**自启**（Systemd）
- `mv -f ss-tproxy.service /etc/systemd/system`
- `systemctl daemon-reload`
- `systemctl enable ss-tproxy.service`

**自启**（SysVinit）
- `touch /etc/rc.d/rc.local`
- `chmod +x /etc/rc.d/rc.local`
- `echo '/usr/local/bin/ss-tproxy start' >>/etc/rc.d/rc.local`

如果 ss-tproxy 主机使用 PPPoE 拨号上网（或其它耗时较长的方式），配置自启后，可能导致 ss-tproxy 在网络还未完全准备好的情况下先运行。此时如果 ss-tproxy.conf 中的 `v2ray_server`、`tlspxy_server`、`socks5_remote`、`server_addr` 为域名，则会导致 ss-tproxy 启动失败（甚至卡一段时间，因为它一直在尝试解析这些域名，直到超时为止）。要恢复正常的代理，只能在启动完成后手动进行 `ss-tproxy restart`。如果你想避免这种情况，请尽量将 ss-tproxy.conf 中的 `v2ray_server`、`tlspxy_server`、`socks5_remote`、`server_addr` 替换为 IP 形式，或者将这些域名添加到 ss-tproxy 主机的 /etc/hosts 文件，如果你和我一样使用的 ArchLinux，那么最好的解决方式就是利用 netctl 的 hook 启动 ss-tproxy（如拨号成功后再启动 ss-tproxy），具体配置可参考 [Arch 官方文档](https://wiki.archlinux.org/index.php/netctl#Using_hooks)。

**用法**
- `ss-tproxy help`：查看帮助
- `ss-tproxy start`：启动代理
- `ss-tproxy stop`：关闭代理
- `ss-tproxy restart`：重启代理
- `ss-tproxy status`：代理状态
- `ss-tproxy check-depend`：检查依赖
- `ss-tproxy flush-cache`：清空 DNS 缓存
- `ss-tproxy flush-gfwlist`：清空 ipset-gfwlist IP 列表
- `ss-tproxy update-gfwlist`：更新 gfwlist（restart 生效）
- `ss-tproxy update-chnonly`：更新 chnonly（restart 生效）
- `ss-tproxy update-chnroute`：更新 chnroute（restart 生效）
- `ss-tproxy dump-ipts`：显示 iptables 的 mangle、nat 表规则
- `ss-tproxy flush-ipts`：清空 raw、mangle、nat、filter 表规则

`ss-tproxy flush-gfwlist` 的作用：因为 `*gfwlist*` 模式下 `ss-tproxy restart`、`ss-tproxy stop; ss-tproxy start` 并不会清空 `ipset-gfwlist` 列表，所以如果你进行了 `ss-tproxy update-gfwlist`、`ss-tproxy update-chnonly` 操作，或者修改了 `/etc/tproxy/gfwlist.ext` 文件，建议在 start 前执行一下此步骤，防止因为之前遗留的 ipset-gfwlist 列表导致奇怪的问题。注意，如果执行了 `ss-tproxy flush-gfwlist` 那么你可能需要还清空内网主机的 dns 缓存，并重启浏览器等被代理的应用。

如果需要切换代理 mode，必须先执行 `ss-tproxy stop`，然后再修改配置文件，改完之后再执行 `ss-tproxy start`。你可能会问为什么不能简单的改完文件直接 `ss-tproxy restart`？因为 ss-tproxy 只是一个 shell 脚本，它的一切状态都是靠 ss-tproxy.conf 文件保持的，如果你在修改 mode 之前没有先执行 stop 操作，那么 ss-tproxy 是不可能知道脚本之前用的是什么 mode，这样就会导致待会的 restart 操作出现问题（restart 在内部其实就是先调用 stop 函数，再调用 start 函数），执行 stop 函数时，脚本获取的 mode 其实是改了之后的 mode，所以执行清理操作时（主要是 kill 相关进程），不会清理先前那个 mode 的相关进程，然后在调用 start 函数时，新启动的进程可能会与之前的进程产生监听端口冲突，导致代理配置失败。当然，如果你没有修改 mode，那么是完全可以先改配置文件再执行 `ss-tproxy restart` 的。

**日志**
> 脚本默认关闭了日志输出，如果需要，请修改 ss-tproxy.conf，打开相应的 log/verbose 选项

- ss-redir：`/var/log/ss-redir.log`
- ss-tunnel：`/var/log/ss-tunnel.log`
- tun2socks：`/var/log/tun2socks.log`
- dnsmasq：`/var/log/dnsmasq.log`
- chinadns：`/var/log/chinadns.log`
- dnsforwarder：`/var/log/dnsforwarder.log`

## 已知问题
- 由于 v2ray 的 `dokodemo-door` 传入协议无法正确处理 QUIC（Quick UDP Internet Connections）协议，导致访问支持 QUIC 协议的网站极其不稳定，具体表现为：网页加载不全、Google Play 图片无法显示、Google Play 软件无法下载及更新，虽然可以在 Chrome 浏览器中关闭 QUIC 协议的支持，但是 Google Play 没这个选项。搜索一番后，找到一个解决方法（讨论此问题的 Issue：<https://github.com/v2ray/v2ray-core/issues/819>）：在 `dokodemo-door` 配置段中添加 `"domainOverride": ["quic"]`。但是实际测试并没有多好的效果，时好时坏，而且 Google Play 的加载速度比 SS/SSR 慢多了。

## 更新计划
- 内网主机黑名单（全走代理）、白名单（全走直连）支持，方便部分游戏用户
- 精简 ss-tproxy 脚本，特别是 `check_depend`、`start_dns`、`status` 这几个函数
- 自写 v2ray websocket + tls 模式的 C 语言版（[tls-proxy](https://github.com/zfl9/tls-proxy)），自用于 RPi3B/Android

## 更多信息
- [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)
- [chinadns](https://github.com/shadowsocks/ChinaDNS)
- [dnsforwarder](https://github.com/holmium/dnsforwarder)
- [gotun2socks](https://github.com/yinghuocho/gotun2socks)
- [v2ray-core](https://github.com/v2ray/v2ray-core)
- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
- [shadowsocksr-libev](https://github.com/shadowsocksr-backup/shadowsocksr-libev)
- [gfwlist2dnsmasq](https://github.com/zfl9/gfwlist2dnsmasq)
- [ss-redir 透明代理](https://www.zfl9.com/ss-redir.html)
