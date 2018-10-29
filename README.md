# Linux TCP+UDP 透明代理
## 脚本简介
ss-tproxy 目前存在 3 个版本，分别为 v1、v2、v3。最初编写 ss-tproxy 脚本的目的很简单，就是为了透明代理 ss/ssr，这也是脚本名称的由来。在 v1 版本中，ss-tproxy 只实现了 chnroute 大陆地址分流模式，因为我这边的网络即使访问普通的国外网站也很慢，所以干脆将国外网站都走代理。随着 ss-tproxy 被 star 的数量越来越多，促使我编写了 v2 版本，v2 版本先后实现了 global、gfwlist、chnonly、chnroute 四种分流模式，并且合并了 [ss-tun2socks](https://github.com/zfl9/ss-tun2socks)，支持 ss/ssr/v2ray/socks5 的透明代理。因脚本结构问题，导致 v2 版本的代码行数达到了 1300+，使得脚本过于臃肿且难以维护，最终催生了现在的 v3 版本。

ss-tproxy v3 基本上可以认为是 ss-tproxy v2 的精简优化版，v3 版本去掉了很多不是那么常用的代理模式，如 tun2socks、tcponly，并提取出了 ss/ssr/v2ray 等代理软件的相同规则，所以 v3 版本目前只有两大代理模式：REDIRECT + TPROXY、TPROXY + TPROXY（纯 TPROXY 方式）。REDIRECT + TPROXY 是指 TCP 使用 REDIRECT 方式代理而 UDP 使用 TPROXY 方式代理；纯 TPROXY 方式则是指 TCP 和 UDP 均使用 TPROXY 方式代理。目前来说，ss-libev、ssr-libev、v2ray-core、redsocks2 均为 REDIRECT + TPROXY 组合方式，而最新版 v2ray-core 则支持纯 TPROXY 方式的代理。在 v3 中，究竟使用哪种组合是由 `proxy_tproxy='boolean_value'` 决定的，如果为 true 则为纯 TPROXY 模式，否则为 REDIRECT + TPROXY 模式（默认）。

v3 版本仍然实现了 global、gfwlist、chnonly、chnroute 四种分流模式；global 是指全部流量都走代理；gfwlist 是指 gfwlist.txt 与 gfwlist.ext 列表中的地址走代理，其余走直连；chnonly 本质与 gfwlist 没区别，只是 gfwlist.txt 与 gfwlist.ext 列表中的域名为大陆域名，所以 chnonly 是国外翻回国内的专用模式；chnroute 则是从 v1 版本开始就有的模式，chnroute 模式会放行特殊地址、国内地址的流量，然后其它的流量（发往国外的流量）都会走代理出去（默认）。

如果你需要使用 tun2socks 模式（socks5 透明代理）、tcponly 模式（仅代理 TCP 流量），请转到 [ss-tproxy v2 版本](https://github.com/zfl9/ss-tproxy/tree/v2-master)。关于 tcponly 模式，可能以后会在 v3 版本中加上，但目前暂时不考虑。而对于 socks5 透明代理，我不是很建议使用 tun2socks，因为 tun2socks 是 golang 写的一个程序，在树莓派上性能堪忧（v2ray 也是如此），即使你认为性能可以接受，我还是建议你使用 [redsocks2](https://github.com/semigodking/redsocks) 来配合 v3 脚本的 REDIRECT + TPROXY 模式（当然如果你的 socks5 代理仅支持 TCP，那么目前还是只能用 v2 的 tun2socks 模式，直到 v3 的 tcponly 模式上线）。使用 redsocks2 配合 REDIRECT + TPROXY 模式很简单，配置好 redsocks2 之后，在 ss-tproxy.conf 的 runcmd 中填写 redsocks2 的启动命令就行。

ss-tproxy 可以运行在 Linux 软路由/网关、Linux 物理机、Linux 虚拟机等环境中，可以透明代理 ss-tproxy 主机本身以及所有网关指向 ss-tproxy 主机的其它主机的 TCP 与 UDP 流量。透明代理主机本身的 TCP 和 UDP 没什么好讲的，我主要说一下透明代理"其它主机"的 TCP 和 UDP 的流量。即使 ss-tproxy 不是运行在 Linux 软路由/网关上，但通过某些"技巧"，ss-tproxy 依旧能够透明代理其它主机的 TCP 与 UDP 流量。比如你在某台内网主机（假设 IP 地址为 192.168.0.100）中运行 ss-tproxy，那么你只要将该内网中的其它主机的网关以及 DNS 服务器设为 192.168.0.100，那么这些内网主机的 TCP 和 UDP 就会被透明代理。当然这台内网主机可以是一个 Linux 虚拟机（网络要设为桥接模式，通常只需一张网卡），假设这台虚拟机的 IP 为 192.168.0.200，虚拟机能够与内网中的其它主机正常通信，也能够正常上外网，那么你只需将内网中的其它主机的网关和 DNS 设为 192.168.0.200 就可以透明代理它们的 TCP 与 UDP 流量。

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

`proxy` 配置段中的 `proxy_server` 可以填写域名、也可以填写 IP，不作要求；`proxy_runcmd` 是用来启动代理软件的命令，此命令不可以占用前台，否则 `ss-tproxy start` 将被阻塞；`proxy_kilcmd` 是用来停止代理软件的命令。常见的写法：
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

`ss-tproxy flush-gfwlist` 的作用：因为 `gfwlist` 模式下 `ss-tproxy restart`、`ss-tproxy stop; ss-tproxy start` 并不会清空 `ipset-gfwlist` 列表，所以如果你进行了 `ss-tproxy update-gfwlist`、`ss-tproxy update-chnonly` 操作，或者修改了 `/etc/tproxy/gfwlist.ext` 文件，建议在 start 前执行一下此步骤，防止因为之前遗留的 ipset-gfwlist 列表导致奇怪的问题。注意，如果执行了 `ss-tproxy flush-gfwlist` 那么你可能需要还清空内网主机的 dns 缓存，并重启浏览器等被代理的应用。

如果需要修改 `proxy_kilcmd`（比如将 ss 改为 ssr），请先执行 `ss-tproxy stop` 再修改配置文件，否则之前的代理进程不会被 kill，这可能会造成端口冲突。

**日志**
> 脚本默认关闭了详细日志，如果需要，请修改 ss-tproxy.conf，打开相应的 log/verbose 选项

- dnsmasq：`/var/log/dnsmasq.log`
- chinadns：`/var/log/chinadns.log`
