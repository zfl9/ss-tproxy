# Linux TCP+UDP 透明代理
## 脚本简介
ss-tproxy 目前存在 3 个版本，分别为 v1、v2、v3。最初编写 ss-tproxy 脚本的目的很简单，就是为了透明代理 ss/ssr，这也是脚本名称的由来。在 v1 版本中，ss-tproxy 只实现了 chnroute 大陆地址分流模式，因为我这边的网络即使访问普通的国外网站也很慢，所以干脆将国外网站都走代理。随着 ss-tproxy 被 star 的数量越来越多，促使我编写了 v2 版本，v2 版本先后实现了 global、gfwlist、chnonly、chnroute 四种分流模式，并且合并了 [ss-tun2socks](https://github.com/zfl9/ss-tun2socks)，支持 ss/ssr/v2ray/socks5 的透明代理。但因脚本结构问题，导致 v2 版本的代码行数达到了 1300+，使得脚本过于臃肿且难以维护，最终催生了现在的 v3 版本。

ss-tproxy v3 基本上可以认为是 ss-tproxy v2 的精简优化版，v3 版本去掉了很多不是那么常用的代理模式，如 tun2socks、tcponly，并提取出了 ss/ssr/v2ray 等代理软件的相同规则，所以 v3 版本目前只有两大代理模式：REDIRECT + TPROXY、TPROXY + TPROXY（纯 TPROXY 方式）。REDIRECT + TPROXY 是指 TCP 使用 REDIRECT 方式代理而 UDP 使用 TPROXY 方式代理；纯 TPROXY 方式则是指 TCP 和 UDP 均使用 TPROXY 方式代理。目前来说，ss-libev、ssr-libev、v2ray-core、redsocks2 均为 REDIRECT + TPROXY 组合方式，而最新版 v2ray-core 则支持纯 TPROXY 方式的代理。在 v3 中，究竟使用哪种组合是由 `proxy_tproxy='boolean_value'` 决定的，如果为 true 则为纯 TPROXY 模式，否则为 REDIRECT + TPROXY 模式（默认）。

v3 版本仍然实现了 global、gfwlist、chnonly、chnroute 四种分流模式；global 是指全部流量都走代理；gfwlist 是指 gfwlist.txt 与 gfwlist.ext 列表中的地址走代理，其余走直连；chnonly 本质与 gfwlist 没区别，只是 gfwlist.txt 与 gfwlist.ext 列表中的域名为大陆域名，所以 chnonly 是国外翻回国内的专用模式；chnroute 则是从 v1 版本开始就有的模式，chnroute 模式会放行特殊地址、国内地址的流量，然后其它的流量（发往国外的流量）都会走代理出去（默认）。

如果你需要使用 tun2socks 模式（socks5 透明代理）、tcponly 模式（仅代理 TCP 流量），请转到 [ss-tproxy v2 版本](https://github.com/zfl9/ss-tproxy/tree/v2-master)。关于 tcponly 模式，可能以后会在 v3 版本中加上，但目前暂时不考虑。而对于 socks5 透明代理，我不是很建议使用 tun2socks，因为 tun2socks 是 golang 写的一个程序，在树莓派上性能堪忧（v2ray 也是如此），即使你认为性能可以接受，我还是建议你使用 [redsocks2](https://github.com/semigodking/redsocks) 来配合 v3 脚本的 REDIRECT + TPROXY 模式（当然如果你的 socks5 代理仅支持 TCP，那么目前还是只能用 v2 的 tun2socks 模式，直到 v3 的 tcponly 模式上线）。使用 redsocks2 配合 REDIRECT + TPROXY 模式很简单，配置好 redsocks2 之后，在 ss-tproxy.conf 的 runcmd 中填写 redsocks2 和 socks5 代理的启动命令就行。

ss-tproxy 可以运行在 Linux 软路由/网关、Linux 物理机、Linux 虚拟机等环境中，可以透明代理 ss-tproxy 主机本身以及所有网关指向 ss-tproxy 主机的其它主机的 TCP 与 UDP 流量。透明代理主机本身的 TCP 和 UDP 没什么好讲的，我主要说一下透明代理"其它主机"的 TCP 和 UDP 的流量。即使 ss-tproxy 不是运行在 Linux 软路由/网关上，但通过某些"技巧"，ss-tproxy 依旧能够透明代理其它主机的 TCP 与 UDP 流量。比如你在某台内网主机（假设 IP 地址为 192.168.0.100）中运行 ss-tproxy，那么你只要将该内网中的其它主机的网关以及 DNS 服务器设为 192.168.0.100，那么这些内网主机的 TCP 和 UDP 就会被透明代理。当然这台内网主机可以是一个 Linux 虚拟机（网络要设为桥接模式，通常只需一张网卡），假设这台虚拟机的 IP 为 192.168.0.200，虚拟机能够与内网中的其它主机正常通信，也能够正常上外网，那么你只需将内网中的其它主机的网关和 DNS 设为 192.168.0.200 就可以透明代理它们的 TCP 与 UDP 流量。

如果你不是在 Linux 软路由/网关上运行 ss-tproxy（这里说的“软路由/网关”就是普通意义上的“路由器”，也就是说 ss-tproxy 主机至少有两张网卡，一张网卡连接外网，一张网卡连接内网），那么请将 ss-tproxy.conf 里面的 `ipts_non_snat` 改为 `true`，否则路由上设置的端口映射规则将无法正常工作（当然，这个选项对于 global 分流模式没有效果，这个以后再说吧，毕竟也很少人使用 global 分流模式）。

## 脚本依赖
- [ss-tproxy 脚本相关依赖的安装方式的参考](https://www.zfl9.com/ss-redir.html#%E5%AE%89%E8%A3%85%E4%BE%9D%E8%B5%96)
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
- 如需配置 gfwlist 扩展列表，请编辑 `/etc/ss-tproxy/gfwlist.ext`，然后重启脚本生效

`proxy` 配置段中的 `proxy_server` 是代理服务器的地址，可以填域名也可以填 IP，不作要求（但并不是说这个选项就能随便写，你必须保证 `proxy_server` 的地址与 `proxy_runcmd` 里面的服务器地址保持一致，否则 iptables 规则将会出现死循环）；`proxy_runcmd` 是用来启动代理软件的命令，此命令不可以占用前台（意思是说这个命令必须能够立即返回），否则 `ss-tproxy start` 将被阻塞；`proxy_kilcmd` 是用来停止代理软件的命令。常见的写法有：
```bash
# runcmd
command <args...>
service srvname start
systemctl start srvname
/path/to/start.proxy.script
(command <args...> </dev/null &>>/var/log/proc.log &)
setsid command <args...> </dev/null &>>/var/log/proc.log
nohup command <args...> </dev/null &>>/var/log/proc.log &
command <args...> </dev/null &>>/var/log/proc.log & disown

# kilcmd
pkill -9 command
service srvname stop
systemctl stop srvname
kill -9 $(pidof command)

# example
service v2ray start
systemctl start v2ray
systemctl start ss-redir
systemctl start ssr-redir
(ss-redir <args...> </dev/null &>>/var/log/ss-redir.log &)
(ssr-redir <args...> </dev/null &>>/var/log/ssr-redir.log &)

# ss-redir args
-s <server_addr>    # 服务器地址
-p <server_port>    # 服务器端口
-m <server_method>  # 加密方式
-k <server_passwd>  # 用户密码
-b <listen_addr>    # 监听地址
-l <listen_port>    # 监听端口
--no-delay          # TCP_NODELAY
--fast-open         # TCP_FASTOPEN
--reuse-port        # SO_REUSEPORT
-u                  # 启用 udp relay
-v                  # 启用详细日志输出

# ssr-redir args
-s <server_addr>    # 服务器地址
-p <server_port>    # 服务器端口
-m <server_method>  # 加密方式
-k <server_passwd>  # 用户密码
-b <listen_addr>    # 监听地址
-l <listen_port>    # 监听端口
-O <protocol>       # 协议插件
-G <protocol_param> # 协议参数
-o <obfs>           # 混淆插件
-g <obfs_param>     # 混淆参数
-u                  # 启用 udp relay
-v                  # 启用详细日志输出
```

如果还是没看懂，我再举几个具体的例子：
```bash
# ss-libev 透明代理
# 假设服务器信息如下:
# 服务器地址: ss.net
# 服务器端口: 8080
# 加密方式:   aes-128-gcm
# 用户密码:   passwd.ss.net
# 监听地址:   0.0.0.0
# 监听端口:   60080
# proxy_runcmd 如下:
(ss-redir -s ss.net -p 8080 -m aes-128-gcm -k passwd.ss.net -b 0.0.0.0 -l 60080 -u --reuse-port --no-delay --fast-open </dev/null &>>/var/log/ss-redir.log &)
# proxy_kilcmd 如下:
kill -9 $(pidof ss-redir)

# ssr-libev 透明代理
# 假设服务器信息如下:
# 服务器地址: ss.net
# 服务器端口: 8080
# 加密方式:   aes-128-cfb
# 用户密码:   passwd.ss.net
# 协议插件:   auth_chain_a
# 协议参数:   2333:protocol_param
# 混淆插件:   http_simple
# 混淆参数:   www.bing.com
# 监听地址:   0.0.0.0
# 监听端口:   60080
# proxy_runcmd 如下:
# 如果没有协议参数、混淆参数，则去掉 -G、-g 选项
(ssr-redir -s ss.net -p 8080 -m aes-128-cfb -k passwd.ss.net -O auth_chain_a -G 2333:protocol_param -o http_simple -g www.bing.com -b 0.0.0.0 -l 60080 -u </dev/null &>>/var/log/ssr-redir.log &)
# proxy_kilcmd 如下:
kill -9 $(pidof ssr-redir)

# v2ray 透明代理:
# 对于 Systemd 发行版
proxy_runcmd='systemctl start v2ray'
proxy_kilcmd='systemctl stop  v2ray'
# 对于 SysVinit 发行版
proxy_runcmd='service v2ray start'
proxy_kilcmd='service v2ray stop'
```
对于 ss-libev、ssr-libev，也可以将相关配置信息写入 json 文件，然后使用选项 `-c /path/to/config.json` 来运行。<br>
特别注意，ss-redir、ssr-redir 的监听地址必须要设置为 0.0.0.0（即 `-b 0.0.0.0`），不能为 127.0.0.1，也不能省略。

如果使用 v2ray（只介绍 REDIRECT + TPROXY 方式），你必须配置 v2ray 客户端的 `dokodemo-door` 传入协议，如：
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
        ...
    ],
    "outbound": { ... },
    "outboundDetour": [ ... ],
    "routing": { ... }
}
```

如果使用 chnonly 模式（国外翻进国内），请选择 `gfwlist` mode，chnonly 模式下，你必须修改 ss-tproxy.conf 中的 `dns_remote` 为国内的 DNS，如 `dns_remote='114.114.114.114:53'`，并将 `dns_direct` 改为本地 DNS（国外的），如 `dns_direct='8.8.8.8'`；因为 chnonly 模式与 gfwlist 模式共享 gfwlist.txt、gfwlist.ext 文件，所以在第一次使用时你必须先运行 `ss-tproxy update-chnonly` 将默认的 gfwlist.txt 内容替换为大陆域名（更新列表时，也应使用 `ss-tproxy update-chnonly`），并且注释掉 gfwlist.ext 中的 Telegram IP 段，因为这是为正常翻墙设置的。要恢复 gfwlist 模式的话，请进行相反的步骤。

`dns_modify='boolean_value'` 选项：如果值为 false（默认），那么 ss-tproxy 在修改 /etc/resolv.conf 文件时，会采用 `mount -o bind` 方式（不修改原文件，而是“覆盖”，stop 时会自动恢复为原来的文件）；如果值为 true，则直接使用 I/O 重定向来修改 /etc/resolv.conf 文件。一般情况下你不用理会这个选项，但如果 ss-tproxy 主机的网络需要经常变更，那么系统可能会修改 resolv.conf 文件，在这种情况下，当你执行 `ss-tproxy stop` 之后，主机可能会无法正常上网（因为刚才系统修改的文件其实是 `mount -o bind` 上去的，而不是“底层”的那个 resolv.conf）。

**桥接模式**
![桥接模式 - 网络拓扑](https://user-images.githubusercontent.com/22726048/47959326-e07fa280-e01b-11e8-95e5-32953cdbc803.png)
上图由 [@myjsqmail](https://github.com/myjsqmail) 提供，他的想法是，在不改变原网络的情况下，让 ss-tproxy 透明代理内网中的所有 TCP、UDP 流量。为了达到这个目的，他在“拨号路由”下面接了一个“桥接主机”，桥接主机有两个网口，一个连接出口路由（假设为 wan），一个连接内网总线（假设为 lan），然后将这两张网卡进行桥接，得到一个逻辑网卡（假设为 br0），在桥接主机上开启“软路由功能”，即执行 `sysctl -w net.ipv4.ip_forward=1`，然后通过 DHCP 方式，获取出口路由上分配的 IP 信息，此时，桥接主机和其它内网主机已经能够正常上网了。

然后，在桥接主机上运行 ss-tproxy，此时，桥接主机自己能够被正常代理，但是其它内网主机仍然走的直连，没有走透明代理。为什么呢？因为默认情况下，经过网桥的流量不会被 iptables 处理。所以我们必须让网桥上的流量经过 iptables 处理，首先，执行命令 `modprobe br_netfilter` 以加载 br_netfilter 内核模块，然后修改 /etc/sysctl.conf，添加：
```bash
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0

net.ipv4.conf.all.route_localnet = 1
net.ipv4.conf.default.route_localnet = 1

net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-arptables = 1
```
保存退出，然后执行 `sysctl -p` 来让这些内核参数生效。

但这还不够，我们还需要设置 ebtables 规则，首先，安装 ebtables，如 `yum -y install ebtables`，然后执行：
```bash
ebtables -t broute -A BROUTING -p IPv4 -i lan --ip-proto tcp -j redirect --redirect-target DROP
ebtables -t broute -A BROUTING -p IPv4 -i wan --ip-proto tcp -j redirect --redirect-target DROP
ebtables -t broute -A BROUTING -p IPv4 -i lan --ip-proto udp --ip-dport ! 53 -j redirect --redirect-target DROP
ebtables -t broute -A BROUTING -p IPv4 -i wan --ip-proto udp --ip-sport ! 53 -j redirect --redirect-target DROP
```

如果 `proxy_tproxy` 为 false，那么你还需要修改 ss-tproxy 里面的 iptables 规则，将 REDIRECT 改为 DNAT，如：
```bash
# old
iptables -t nat -A TCPCHAIN -p tcp -j REDIRECT --to-ports $proxy_tcport
# new
iptables -t nat -A TCPCHAIN -p tcp -j DNAT --to-destination 127.0.0.1:$proxy_tcport
```

没出什么意外的话，现在桥接主机和其它内网主机的 TCP 和 UDP 流量应该都是能够被 ss-tproxy 给透明代理的。<br>
差点忘了，请将 `/etc/ss-tproxy/ss-tproxy.conf` 里面的 `ipts_non_snat` 选项改为 true，因为不需要 SNAT 规则。

**钩子函数**

ss-tproxy 支持 4 个钩子函数，分别是 `pre_start`（启动前执行）、`post_start`（启动后执行）、`pre_stop`（停止前执行）、`post_stop`（停止后执行）。举个例子，在不修改 ss-tproxy 脚本的前提下，设置一些额外的 iptables 规则，假设我需要在 ss-tproxy 启动后添加某些规则，在 ss-tproxy 停止后删除某些规则，则修改 ss-tproxy.conf，添加以下内容：
```bash
function post_start {
    iptables -A ...
    iptables -A ...
    iptables -A ...
}

function post_stop {
    iptables -D ...
    iptables -D ...
    iptables -D ...
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

注意，上述自启方式并不完美，ss-tproxy 可能会自启失败，主要是因为 ss-tproxy 可能会在网络还未完全准备好的情况下先运行，如果 ss-tproxy.conf 中的 `proxy_server` 为域名（即使是 IP 形式，也可能会失败，因为某些代理软件需要在有网的情况下才能启动成功），那么就会出现域名解析失败的错误，然后导致代理软件启动失败、iptables 规则配置失败等等。缓解方法有：将 `proxy_server` 改为 IP 形式（如果允许的话）；或者将 `proxy_server` 中的域名添加到主机的 `/etc/hosts` 文件；或者使用各种方式让 ss-tproxy 在网络完全启动后再启动。如果你使用的是 ArchLinux，那么最好的自启方式是利用 netctl 的 hook 脚本来启动 ss-tproxy（如拨号成功后再启动 ss-tproxy），具体配置可参考 [Arch 官方文档](https://wiki.archlinux.org/index.php/netctl#Using_hooks)。

**用法**
- `ss-tproxy help`：查看帮助
- `ss-tproxy start`：启动代理
- `ss-tproxy stop`：关闭代理
- `ss-tproxy restart`：重启代理
- `ss-tproxy status`：代理状态
- `ss-tproxy check-command`：检查命令是否存在
- `ss-tproxy flush-dnscache`：清空 DNS 查询缓存
- `ss-tproxy flush-gfwlist`：清空 ipset-gfwlist IP 列表
- `ss-tproxy update-gfwlist`：更新 gfwlist（restart 生效）
- `ss-tproxy update-chnonly`：更新 chnonly（restart 生效）
- `ss-tproxy update-chnroute`：更新 chnroute（restart 生效）
- `ss-tproxy show-iptables`：查看 iptables 的 mangle、nat 表
- `ss-tproxy flush-iptables`：清空 raw、mangle、nat、filter 表

`ss-tproxy flush-gfwlist` 的作用：因为 `gfwlist` 模式下 `ss-tproxy restart`、`ss-tproxy stop; ss-tproxy start` 并不会清空 `ipset-gfwlist` 列表，所以如果你进行了 `ss-tproxy update-gfwlist`、`ss-tproxy update-chnonly` 操作，或者修改了 `/etc/tproxy/gfwlist.ext` 文件，建议在 start 前执行一下此步骤，防止因为之前遗留的 ipset-gfwlist 列表导致奇怪的问题。注意，如果执行了 `ss-tproxy flush-gfwlist` 那么你可能还需要清空内网主机的 dns 缓存，并重启浏览器等被代理的应用。

如果需要修改 `proxy_kilcmd`（比如将 ss 改为 ssr），请先执行 `ss-tproxy stop` 后再修改 `/etc/ss-tproxy/ss-tproxy.conf` 配置文件，否则之前的代理进程不会被 kill（因为 ss-tproxy 不可能再知道之前的 kill 命令是什么，毕竟 ss-tproxy 只是一个 shell 脚本，无法维持状态），这可能会造成端口冲突。

**日志**
> 脚本默认关闭了详细日志，如果需要，请修改 ss-tproxy.conf，打开相应的 log/verbose 选项

- dnsmasq：`/var/log/dnsmasq.log`
- chinadns：`/var/log/chinadns.log`
