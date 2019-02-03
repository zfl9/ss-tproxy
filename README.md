# Linux TCP+UDP 透明代理
## 脚本简介
ss-tproxy v3 是 ss-tproxy v2 的精简优化版，v3 版本去掉了很多不是那么常用的代理模式，如 tun2socks、tcponly，并提取出了 ss/ssr/v2ray 等代理软件的相同规则，所以 v3 版本目前只有两大代理模式：REDIRECT + TPROXY、TPROXY + TPROXY（纯 TPROXY 方式）。REDIRECT + TPROXY 是指 TCP 使用 REDIRECT 方式代理而 UDP 使用 TPROXY 方式代理；纯 TPROXY 方式则是指 TCP 和 UDP 均使用 TPROXY 方式代理。目前来说，ss-libev、ssr-libev、v2ray-core、redsocks2 均为 REDIRECT + TPROXY 组合方式，而最新版 v2ray-core 则支持纯 TPROXY 方式的代理。在 v3 中，究竟使用哪种组合是由 `proxy_tproxy='boolean_value'` 决定的，如果为 true 则为纯 TPROXY 模式，否则为 REDIRECT + TPROXY 模式（默认）。

v3 版本仍然实现了 global、gfwlist、chnonly、chnroute 四种分流模式；global 是指全部流量都走代理；gfwlist 是指 gfwlist.txt 与 gfwlist.ext 列表中的地址走代理，其余走直连；chnonly 本质与 gfwlist 没区别，只是 gfwlist.txt 与 gfwlist.ext 列表中的域名为大陆域名，所以 chnonly 是国外翻回国内的专用模式；chnroute 则是从 v1 版本开始就有的模式，也就是大家熟知的绕过局域网和大陆地址段模式，所以只要是发往国外地址的流量都会走代理出去，这也是 ss-tproxy v3 的默认模式。

ss-tproxy 可以运行在 Linux 软路由/网关、Linux 物理机、Linux 虚拟机等环境中，可以透明代理 ss-tproxy 主机本身以及所有网关指向 ss-tproxy 主机的其它主机的 TCP 与 UDP 流量。即使 ss-tproxy 不是运行在 Linux 软路由/网关上，但通过某些"技巧"，ss-tproxy 依旧能够透明代理其它主机的 TCP 与 UDP 流量。比如你在某台内网主机（假设 IP 地址为 192.168.0.100）中运行 ss-tproxy，那么你只要将该内网中的其它主机的网关以及 DNS 服务器设为 192.168.0.100，那么这些内网主机的 TCP 和 UDP 就会被透明代理。当然这台内网主机也可以是一个 Linux 虚拟机（网络要设为桥接模式，只需要一张网卡）。

## 脚本依赖
- [ss-tproxy 脚本相关依赖的安装方式参考](https://www.zfl9.com/ss-redir.html#%E5%AE%89%E8%A3%85%E4%BE%9D%E8%B5%96)
- global 模式：TPROXY 模块、ip 命令、dnsmasq 命令
- gfwlist 模式：TPROXY 模块、ip 命令、dnsmasq 命令、perl 命令、ipset 命令
- chnroute 模式：TPROXY 模块、ip 命令、dnsmasq 命令、chinadns 命令、ipset 命令

## 端口占用
- global 模式：dnsmasq:60053@tcp+udp
- gfwlist 模式：dnsmasq:60053@tcp+udp
- chnroute 模式：dnsmasq:60053@tcp+udp、chinadns:65353@udp

> 注意：只要当前系统中的其它 dnsmasq 进程不监听 60053 端口，就没有任何影响。

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

`proxy_server` 用来填写服务器的地址，可以是域名也可以是 IP，支持填写多个服务器的地址，使用空格隔开就行。这里解释一下多个服务器地址的作用，其实这个功能是最近才加上去的，也是受到了某位热心网友的启发，在这之前，proxy_server 只能填写一个地址，但是有些时候我们经常需要切换代理服务器，比如现在我手中有 A、B 两台服务器，目前用的是 A 服务器做代理，但是因为某些不可抗拒的因素，A 服务器出了点问题，我需要切换到 B 服务器来上网，那么必须修改 ss-tproxy.conf 里面的 proxy_server，然后修改对应的启动命令以及关闭命令，最后才能执行 `ss-tproxy restart` 来生效，然后过了段时间，发现 A 服务器好了，因为 A 服务器的线路比 B 服务器的好，所以我又想切换回 A 服务器，这时候又要重复上述步骤，改完配置文件再重启 ss-tproxy，非常麻烦。

为了解决这个问题，我将 `proxy_server` 改了一下，让它支持填写多个地址（空格隔开），那么支持填写多个服务器地址又有什么用呢？又是如何解决上述问题的呢？还是以上面的例子为例，我现在将 A、B 两台服务器的地址都填写到 proxy_server 中，默认先使用 A 服务器，然后执行 `ss-tproxy start` 启动代理；那么现在要切换为 B 服务器该如何做呢？很简单，你只需要停止之前的 A 服务器代理进程（假设为 ss-redir，且假设使用 systemctl 管理），即 `systemctl stop ss-redir@A`、`systemctl start ss-redir@B`，就行了，你不需要操作 ss-tproxy 的任何东西，就完成了代理服务器的切换。同理，如果有 5 个常用服务器，也都可以写到 proxy_server 里面，这样 ss-tproxy 启动后基本就不用去管它了，随意切换代理。

`proxy_dports` 用来填写要放行的服务器端口，默认为空，表示所有服务器端口都放行。如果你需要修改此配置，请记得将当前使用的服务器端口给放行（也就是 ss、ssr、v2ray 服务器的监听端口），否则会出现死循环。这个选项也是最近才添加的，原先版本中，默认也是将所有服务器端口都放行，但我最近使用 scp 向 vps 传输文件的时候总是会被 gfw 干扰（没几秒就显示 `stalled`），烦的很，所以就加了这个选项。这个选项的值会被作为 iptables multiport 模块的参数，所以格式为：`port[,port:port,port...]`（方括号和 `...` 不要输进去，这只是格式说明）。比如我的 ss 监听端口为 443，就写 `proxy_dports='443'`；又比如我的 v2ray 监听端口为 1000:2000（动态端口范围），并且我还想放行 80 和 443 端口，就写：`proxy_dports='80,443,1000:2000'`。另外注意，这个选项对 gfwlist 分流模式是没有效果的。

`proxy_runcmd` 是用来启动代理软件的命令，此命令不可以占用前台（意思是说这个命令必须能够立即返回），否则 `ss-tproxy start` 将被阻塞；`proxy_kilcmd` 是用来停止代理软件的命令。`proxy_runcmd` 和 `proxy_kilcmd` 的常见的写法有：
```bash
# runcmd
command args...
service srvname start
systemctl start srvname
/path/to/start.proxy.script
(command args... </dev/null &>>/var/log/proc.log &)
setsid command args... </dev/null &>>/var/log/proc.log
nohup command args... </dev/null &>>/var/log/proc.log &
command args... </dev/null &>>/var/log/proc.log & disown

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
(ss-redir args... </dev/null &>>/var/log/ss-redir.log &)
(ssr-redir args... </dev/null &>>/var/log/ssr-redir.log &)

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

如果还是不清楚怎么写，我再举几个具体的例子：
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
对于 ss-redir/ssr-redir，也可以将配置放到 json 文件，然后使用选项 `-c /path/to/config.json` 替代那一大堆参数。<br>
特别注意，ss-redir、ssr-redir 的监听地址必须要设置为 0.0.0.0（即 `-b 0.0.0.0`），不能为 127.0.0.1，也不能省略。

如果你使用的是 v2ray（此处的配置仅适用于 `2018.11.05 v4.1` 版本之后的 v2ray，含 v4.1 版本），那么你需要像下面这样配置 v2ray 客户端的 config.json（只需关注 `inbounds` 配置段，其它配置与 ss-tproxy 的使用无关），在下面这个例子中，代理方式为 REDIRECT + TPROXY（ss-tproxy 默认代理方式），如果你需要使用纯 TPROXY 代理方式，请将 `"tproxy": "redirect"` 这行注释掉，然后取消 `"tproxy": "tproxy"` 这行的注释，并且将 ss-tproxy.conf 里面的 `proxy_tproxy` 选项改为 true。
```javascript
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "protocol": "dokodemo-door",
      "listen": "0.0.0.0",
      "port": 60080,
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        //"tproxy": "tproxy" // tproxy + tproxy
        "tproxy": "redirect" // redirect + tproxy
      }
    }
  ],

  "outbounds": [
    {
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "node.proxy.net", // server addr
            "port": 12345,               // server port
            "method": "aes-128-gcm",     // server method
            "password": "password"       // server passwd
          }
        ]
      }
    }
  ]
}
```

有人反馈 v2ray 透明代理无法成功，请务必检查 v2ray 客户端和服务端的配置。这是我测试用的 v2ray 配置：

**config.json for client**
```javascript
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "protocol": "dokodemo-door",
      "listen": "0.0.0.0",
      "port": 60080,
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        //"tproxy": "tproxy" // tproxy + tproxy
        "tproxy": "redirect" // redirect + tproxy
      }
    }
  ],

  "outbounds": [
    {
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "node.proxy.net", // VPS 地址
            "port": 12345,               // VPS 端口
            "method": "aes-128-gcm",     // 加密方式
            "password": "password"       // 用户密码
          }
        ]
      }
    }
  ]
}
```

**config.json for server**
```javascript
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "protocol": "shadowsocks",
      "address": "0.0.0.0",      // 监听地址
      "port": 12345,             // 监听端口
      "settings": {
        "method": "aes-128-gcm", // 加密方式
        "password": "password",  // 用户密码
        "network": "tcp,udp"
      }
    }
  ],

  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
```

如果使用 chnonly 模式（国外翻进国内），请选择 `gfwlist` mode，chnonly 模式下，你必须修改 ss-tproxy.conf 中的 `dns_remote` 为国内的 DNS，如 `dns_remote='114.114.114.114:53'`，并将 `dns_direct` 改为本地 DNS（国外的），如 `dns_direct='8.8.8.8'`；因为 chnonly 模式与 gfwlist 模式共享 gfwlist.txt、gfwlist.ext 文件，所以在第一次使用时你必须先运行 `ss-tproxy update-chnonly` 将默认的 gfwlist.txt 内容替换为大陆域名（更新列表时，也应使用 `ss-tproxy update-chnonly`），并且注释掉 gfwlist.ext 中的 Telegram IP 段，因为这是为正常翻墙设置的。要恢复 gfwlist 模式的话，请进行相反的步骤。

`dns_modify='boolean_value'`：如果值为 false（默认），则 ss-tproxy 在修改 /etc/resolv.conf 文件时，会采用 `mount -o bind` 方式（不直接修改原文件，而是“覆盖”它，在 stop 之后会自动恢复为原文件）；如果值为 true，则直接使用 I/O 重定向来修改 /etc/resolv.conf 文件。一般情况下保持默认就行，但某些时候将其设为 true 可能会好一些（具体什么时候我也不太好讲，需要具体情况具体分析，比如你使用默认的 mount 方式出现了问题，那就换为重定向方式）。

`opts_ss_netstat='auto|netstat|ss'` 选项的意思是，在检测 tcp/udp 端口时，应该使用哪个检测命令，默认为 auto，表示自动选择（如果有 ss 就使用 ss，否则使用 netstat），设为 netstat 表示使用 netstat 命令来检测，设为 ss 表示使用 ss 命令来检测。之所以添加这个选项，是因为某些系统的 ss 命令有问题，检测不到 udp 的监听端口，导致用户误以为 udp 端口没有起来。如果你也遇到了这个问题，请将该选项改为 netstat。

`ipts_non_snat='true|false'` 选项的意思是，是否需要设置 SNAT/MASQUERADE 规则，如果为 true 则表示不设置 SNAT/MASQUERADE 规则，如果为 false 则表示要设置 SNAT/MASQUERADE 规则（默认值）。如果你使用“代理网关”或者“透明桥接”模式，请将该选项改为 true，因为不需要 SNAT/MASQUERADE 规则，只有当你在“出口路由”位置运行 ss-tproxy 时才需要配置 SNAT/MASQUERADE 规则（所谓出口路由位置就是至少有两张网卡，一张连接外网，一张连接内网）。

**端口映射**

如果 ss-tproxy 运行在“代理网关”，最好将 `ipts_non_snat` 设为 true，否则端口映射必定失败（好吧，即使将其设为 true，在某些情况下端口映射依旧会失败）。我们先来简要分析一下，为什么设为 false 会导致端口映射失败。假设拨号网关为 192.168.1.1，代理网关为 192.168.1.2，内网主机为 192.168.1.100；在拨号网关上设置端口映射规则，将外网端口 8443 映射到内网主机 192.168.1.100 的 8443 端口；在代理网关上运行 ss-tproxy（假定分流模式为 gfwlist），然后将内网主机 192.168.1.100 的网关和 DNS 设为 192.168.1.2；此时代理网关以及内网主机均可透过代理来上网。

在内网主机 192.168.1.100 上运行端口为 8443 的服务进程，然后我们从其它外网主机（假设 IP 为 2.2.2.2）连接此端口上的服务。首先，外网主机向拨号网关的 8443 端口发起连接（假设 IP 为 1.1.1.1），即 `2.2.2.2:2333 -> 1.1.1.1:8443`，然后拨号网关查询到对应的端口映射规则，于是做 DNAT 转换，变为 `2.2.2.2:2333 -> 192.168.1.100:8443`，然后通过内网网卡送到了 192.168.1.100 主机的 8443 端口（SYN 握手请求成功到达）；然后服务进程会发送 SYN+ACK 握手响应包，即 `192.168.1.100:8443 -> 2.2.2.2:2333`，因为内网主机的网关为 192.168.1.2，所以 SYN+ACK 包将被送到代理网关上，因为目的地址 2.2.2.2 并没有在 gfwlist 列表中，所以放行，经过 FORWARD 链，到达 POSTROUTING 链，问题来了，ss-tproxy 已经在 POSTROUTING 链的 nat 表上设置了 SNAT 规则（`ipts_non_snat` 为 false），所以将被转换为 `192.168.1.2:6666 -> 2.2.2.2:2333`，而当这个数据包到达拨号网关时，拨号网关检查发现这个源地址并不是 192.168.1.100:8443，所以并不会按照端口映射规则将其转换为 `1.1.1.1:8443 -> 2.2.2.2:2333`，而是将其映射为一个随机端口，如 62333，所以外网主机接收到的 SYN+ACK 包的源地址是 1.1.1.1:62333，这显然是无法成功建立 TCP 连接的。

所以，对于 gfwlist 模式，只需要将 `ipts_non_snat` 设为 true，端口映射基本上就能正常工作。而对于 chnroute 模式，即使将 `ipts_non_snat` 设为了 true，在某些情况下依旧会失败，怎么说呢？比如你在 IP 为非 chnroute list 的外网主机上连接拨号网关上的映射端口，SYN 包没问题，会成功到达内网主机，但是 SYN+ACK 包在经过代理网关时，因为这个目的 IP 并不位于 chnroute list，所以会被送到代理网关上的代理进程（比如 ss-redir），也就是说这个 SYN+ACK 包会走代理出去，这显然会握手失败。如果你要让它握手成功，就必须将对应的目的 IP 放行，或者改用 gfwlist 模式。而 global 模式就不用说了，无论目的 IP 是国内还是国外，通通走代理，所以全都会握手失败，解决方法和 chnroute 模式一样，要么放行，要么用 gfwlist 模式。

但实际上，如果内网主机需要映射到外网，那么它们通常也不需要设置什么代理（即不用将网关和 dns 指向 ss-tproxy 主机），而不更改这些主机的 gateway 和 dns 自然就不会出现上述端口映射问题，因为根本不会经过 ss-tproxy，无论去程还是回程。

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
ebtables -t broute -A BROUTING -p IPv4 -i lan --ip-proto udp --ip-dport ! 53 -j redirect --redirect-target DROP
```

如果 `proxy_tproxy` 为 false，那么你还需要修改 ss-tproxy 里面的 iptables 规则，将 REDIRECT 改为 DNAT，如：
```bash
# old
iptables -t nat -A TCPCHAIN -p tcp -j REDIRECT --to-ports $proxy_tcport
# new
iptables -t nat -A TCPCHAIN -p tcp -j DNAT --to-destination 127.0.0.1:$proxy_tcport
```

没出什么意外的话，现在桥接主机和其它内网主机的 TCP 和 UDP 流量应该都是能够被 ss-tproxy 给透明代理的。<br>
还有一点，请将 `/etc/ss-tproxy/ss-tproxy.conf` 里面的 `ipts_non_snat` 选项改为 true，因为不需要 SNAT 规则。

**钩子函数**

ss-tproxy 支持 4 个钩子函数，分别是 `pre_start`（启动前执行）、`post_start`（启动后执行）、`pre_stop`（停止前执行）、`post_stop`（停止后执行）。举个例子，在不修改 ss-tproxy 脚本的前提下，设置一些额外的 iptables 规则，假设我需要在 ss-tproxy 启动后添加某些规则，然后在 ss-tproxy 停止后删除这些规则，则修改 ss-tproxy.conf，添加以下内容：
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

**自启**
- `mv -f ss-tproxy.service /etc/systemd/system`
- `systemctl daemon-reload`
- `systemctl enable ss-tproxy.service`

关于自启我要多说几句，之前的开机自启是有问题的，有一定几率会失败，不过现在已经解决了这个问题，其实说起来解决方法也很简单，就是在启动之前先 ping 114.114.114.114，直到 ping 成功了才会执行 `ss-tproxy start`。经过测试，加了这个 ping 命令后，自启就没有问题了，可以确保在网络准备好之后再启动 ss-tproxy 脚本。当然，如果你使用的是 ArchLinux，也可以利用 netctl 的 hook 脚本来启动 ss-tproxy，具体做法如下：

假设你的网卡配置文件为 `/etc/netctl/eth0`（如果有多张网卡，那就选择“外网网卡”，也就是通过哪张网卡上网就选哪张网卡），进入 `/etc/netctl/hooks` 目录，创建一个空文件（即钩子文件，本质是 shell 脚本），然后给这个文件加上可执行权限（没有执行权限的钩子不会被 netctl 执行），比如我就创建一个名为 eth0.hooks 的文件（文件名随便，无要求）：
```bash
cd /etc/netctl/hooks
touch eth0.hooks
chmod +x eth0.hooks
```
然后使用你喜欢的文本编辑器打开 eth0.hooks 文件，添加以下内容：
```bash
#!/bin/bash

if [ "$Profile" = 'eth0' ]; then
    function onStart {
        /usr/local/bin/ss-tproxy start
        return 0
    }

    function onStop {
        /usr/local/bin/ss-tproxy stop
        return 0
    }

    ExecUpPost='onStart'
    ExecDownPre='onStop'
fi
```
脚本内容本身具有很好的自我解释性，我就不详细解释了，需要注意的是 `"$Profile" = 'eth0'`，因为默认情况下任何一张网卡的启动和停止都会搜寻 `/etc/netctl/hooks` 下的可执行钩子脚本，而我们实际上只需要关心 `/etc/netctl/eth0` 网卡的启动事件和关闭事件，所以就做了一下这个判断。编辑完之后保存退出，然后 reboot 测试一下是否能够正常自启动（当然你的 `/etc/netctl/eth0` 要配置自启动，即 `netctl enable eth0`）。

注意，如果你使用 `systemctl enable ss-tproxy.service` 方式配置了 ss-tproxy 的开机自启，那么应该避免直接使用 `ss-tproxy start|stop|restart` 这几个命令（当然除了这几个命令外，其它命令都是可以执行的，比如 `ss-tproxy status`、`ss-tproxy update-gfwlist`），为什么呢？因为 systemctl 启动一个脚本之后，systemctl 会在内部保存一个状态，即脚本已经 running，然后只有当你下次使用 systemctl 停止该脚本的时候，systemctl 内部才会将这个状态改为 stopped。所以配置 ss-tproxy 开机自启后，这个服务的状态就是 running，如果你执行 `ss-tproxy stop` 来停止脚本，那么这个服务状态是不会变的，依旧是 running，但实际上它已经 stopped 了，而当你执行 `systemctl start ss-tproxy` 来启动脚本时，systemctl 并不会在内部执行 `ss-tproxy start`，因为这个服务的状态是 running，说明已经启动了，就不会再次启动了。这样一来就完全混乱了，你以为执行完毕后 ss-tproxy 就启动了，然而实际上，执行 `ss-tproxy status` 看下还是 stopped 的。所以我说如果配置了 service 方式的开机自启，就不要使用 `ss-tproxy start|stop|restart` 这 3 个命令了！应使用 `systemctl start|stop|restart ss-tproxy`。

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

`ss-tproxy flush-gfwlist` 的作用：因为 `gfwlist` 模式下 `ss-tproxy restart`、`ss-tproxy stop; ss-tproxy start` 并不会清空 `ipset-gfwlist` 列表，所以如果你进行了 `ss-tproxy update-gfwlist`、`ss-tproxy update-chnonly` 操作，或者修改了 `/etc/tproxy/gfwlist.ext` 文件，建议在 start 前执行一下此步骤，防止因为之前遗留的 ipset-gfwlist 列表导致各种奇怪的问题。注意，如果执行了 `ss-tproxy flush-gfwlist` 那么你可能还需要清空内网主机的 dns 缓存，并重启浏览器等被代理的应用。

如果需要修改 `proxy_kilcmd`（比如将 ss 改为 ssr），请先执行 `ss-tproxy stop` 后再修改 `/etc/ss-tproxy/ss-tproxy.conf` 配置文件，否则之前的代理进程不会被 kill（因为 ss-tproxy 不可能再知道之前的 kill 命令是什么，毕竟 ss-tproxy 只是一个 shell 脚本，无法维持状态），这可能会造成端口冲突。当然也有一种取巧的办法，那就是在 proxy_kilcmd 中 kill 所有可能使用到的代理进程，比如你经常需要从 ss 切换为 ssr（或者从 ssr 切换为 ss），那么可以将 proxy_kilcmd 写为 `kill -9 $(pidof ss-redir) $(pidof ssr-redir)`，这样你就不需要先 stop 再改配置再 start 了，而是直接改好配置然后 restart。

小技巧，如果你觉得切换代理时要修改 ss-tproxy.conf 很麻烦，也可以这么做：将 proxy_runcmd 和 proxy_kilcmd 改为空调用，如 `proxy_runcmd='true'`、`proxy_kilcmd='true'`，然后配置好 proxy_server，将所有可能会用到的服务器地址都放进去，当然 proxy_dports 也可以配置好要放行的服务器端口，最后执行 `ss-tproxy start` 来启动 ss-tproxy，因为我们没有写代理进程的启动和停止命令，所以会显示代理进程未运行，没关系，现在我们要做的就是启动对应的代理进程，假设为 ss-redir 且使用 systemd 进行管理，则执行 `systemctl start ss-redir`，现在你再执行 `ss-tproxy status` 就会看到对应的状态正常了，当然代理也是正常的，如果需要换为 v2ray，假设也是使用 systemd 进行管理，那么只需要先关闭 ss-redir，然后再启动 v2ray 就行了，即 `systemctl stop ss-redir`、`systemctl start v2ray`，相当于我现在启动的只是一个代理框架，ss-tproxy 启动之后基本就不需要管它了，可以随意切换代理。

**日志**
> 脚本默认关闭了详细日志，如果需要，请修改 ss-tproxy.conf，打开相应的 log/verbose 选项

- dnsmasq：`/var/log/dnsmasq.log`
- chinadns：`/var/log/chinadns.log`

**FAQ**<br>
[ss-tproxy 常见问题解答](https://www.zfl9.com/ss-redir.html#%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98)
