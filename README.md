# Linux 透明代理

## 什么是正向代理？

科学上网套件通常分为客户端（client）和服务端（server），server 运行在境外服务器（通常为 Linux 服务器），client 运行在本地主机（如 Windows、Linux、Android、iOS）。本文只关心 client。大多数 client 被实现为一个本地的 http、socks5 代理服务器（如 ss-local），一个程序如果想通过 client 科学上网，必须对它进行特定的设置，使其通过 http、socks5 协议与 client 进行通信，这是大多数人的使用方式。这种代理方式，我们称之为 **正向代理**。

## 什么是透明代理？

在正向代理中，一个程序要想走代理，必须显式的对其进行一些设置，对该程序来说，有没有走代理是很明确的，大家都“心知肚明”。而透明代理则与之相反，以 Linux 为例，当我们设置好适当的 iptables 规则后，我们将不再需要显式的配置这些程序来让其经过代理或者不经过代理（直连），因为这些程序传出的流量会自动被 iptables 规则处理，那些我们认为需要走代理的流量，会通过合适的方法送往 client，不需要走代理的流量则直接放行（直连）。这个过程对于我们使用的程序来说是完全透明的，程序自身对其一无所知。这就叫做 **透明代理**。注意，所谓透明是对我们使用的程序（如浏览器）透明，而非对 client、server 或目标网站透明，理解这一点非常重要。

## 透明代理如何工作？

在透明代理中，那些需要走代理的流量，会通过“合适的方法”送往 client。具体到 iptables，有两种方式：

- REDIRECT：支持 TCP 协议的透明代理。
- TPROXY：支持 TCP 和 UDP 协议的透明代理。

为方便叙述，本文以 **纯 TPROXY 模式** 指代 TCP 和 UDP 都使用 TPROXY 来实现，以 **REDIRECT + TPROXY 模式** 指代 TCP 使用 REDIRECT 实现，而 UDP 使用 TPROXY 来实现，有时候简称 **REDIRECT 模式**，它们都是一个意思。

除了 iptables 这边的支持，client 这边当然也需要实现相应的“传入协议”：

- 普通代理：client 实现的是 http、socks5 传入协议。
- 透明代理：client 实现的是 透明代理 传入协议。

以常见的科学上网套件为例：

- ss：ss-libev 的 ss-redir 支持透明代理传入，ss-rust 支持透明代理传入。
- ssr：ssr-libev 的 ssr-redir 支持透明代理传入。
- v2ray：通过 `dokodemo-door` 入站协议来支持透明代理传入。
- trojan：通过 `"run_type": "nat"` 来支持透明代理传入。

不同科学上网套件，对透明代理传入的支持度并不相同：

- ss-libev 支持 TCP 和 UDP 透明代理，3.3.5 版本开始，TCP 支持 TPROXY 传入。
- ssr-libev 支持 TCP 和 UDP 透明代理，TCP 只支持 REDIRECT 传入。
- v2ray 支持 TCP 和 UDP 透明代理，TCP 根据配置可选择 REDIRECT 或 TPROXY 传入。
- trojan 支持 TCP 透明代理，TCP 只支持 REDIRECT 传入。
- trojan-go 支持 TCP 和 UDP 透明代理，TCP 使用 TPROXY 传入。

另外，是否支持 UDP 还取决于 server 端的配置，某些机场可能未开启 UDP。

---

如果 client 端只支持 socks5 传入（绝大部分代理套件都支持此协议），不支持透明代理传入，还能实现透明代理吗？当然可以，我们可以运行这样一个程序，该程序支持透明代理传入，socks5 传出（与 client 通信）：

- [redsocks](https://github.com/darkk/redsocks)：TCP 支持 REDIRECT 传入。
- [redsocks2](https://github.com/semigodking/redsocks)：TCP 支持 TPROXY/REDIRECT 传入，UDP 支持 TPROXY 传入。
- [ipt2socks](https://github.com/zfl9/ipt2socks)：TCP 支持 TPROXY/REDIRECT 传入，UDP 支持 TPROXY 传入。

ipt2socks 是我编写的一个简单 C 程序，只专注于给科学上网套件添加“透明代理”传入支持，编译和使用方法都非常简单，没有配置文件，指定几个命令行参数即可运行。为了方便，ipt2socks 的 [releases](https://github.com/zfl9/ipt2socks/releases) 页面提供了预编译好的二进制。

借助 ipt2socks，你可以将 client 程序运行在其他性能更强的内网机器上（因为代理的加解密比较费性能，尤其是你在低端设备上跑 ss-tproxy，体验会比较明显），ipt2socks 专门做了一些优化，尽可能实现零拷贝，降低性能开销。

## 此脚本的作用及由来

通过上面的介绍，可以知道，在构建透明代理的过程中，需要的仅仅是 iptables、支持透明代理传入的程序，那 ss-tproxy 脚本的作用是什么？如果你尝试搭建过透明代理，那么你就会体会到，这一过程并不容易，你需要设置许多繁琐的 iptables 规则，还要应对国内复杂的 DNS 环境，还要考虑 UDP 透明代理，并且希望实现常见的分流模式，而不是全都走代理。

于是有了 ss-tproxy 脚本，该脚本的目的就是辅助大家快速搭建一个透明代理环境，ss-tproxy 支持 global、gfwlist、chnroute、回国模式 等常见分流模式，以及配套的无污染 DNS 解析/分流服务。你可以在常见 Linux 环境中运行 ss-tproxy，比如路由器、旁路由网关、普通局域网机器、甚至虚拟机（桥接）。可以透明代理 ss-tproxy 本机的 TCP/UDP 流量；同一局域网下的其他机器，也可以随时将 **网关和DNS** 指向 ss-tproxy 主机，接入 ss-tproxy 的透明代理服务。

> 为什么叫做 `ss-tproxy`？因为该脚本最初只支持 ss 透明代理，当然现在并不局限于特定的代理套件。

## 脚本简介

- 支持 global、gfwlist、chnroute 分流，支持回国代理模式。
- 支持 IPv4、IPv6 双栈透明代理，支持 TCP、UDP 透明代理。
- TCP 支持 REDIRECT 和 TPROXY 方式，支持纯 TPROXY 模式。
- 只代理"主动出站"的流量，不影响 DMZ 主机、端口映射等应用。
- 使用 [chinadns-ng](https://github.com/zfl9/chinadns-ng) 替代原版 chinadns，支持黑白名单、ipset 操作。
- 自带一套开箱即用的 DNS 解析方案，也允许用户[自定义 DNS 方案](https://github.com/zfl9/ss-tproxy/wiki/DNS方案)。

---

脚本自带的分流模式，从本质上说，就是 **白名单**、**黑名单** 的各种组合：

- `global`：**白名单模式**，白名单走直连（保留地址），其余走代理。
- `gfwlist`：**黑名单模式**，黑名单走代理（gfwlist域名），其余走直连。
- `chnroute`：**黑名单+白名单**，黑名单走代理（gfwlist域名），白名单走直连（保留地址，大陆域名/地址），其余走代理（国外域名/地址），黑名单优先级高于白名单（对于ipset）。
- 回国模式：本质还是 gfwlist 模式，具体使用说明见 ss-tproxy.conf。

> 有人可能会疑问，为什么使用 ss-tproxy 后，可以访问谷歌，但无法 ping 谷歌？<br>
因为 ping 走的是 ICMP 协议，几乎没有哪个代理会处理 ICMP，所以 ICMP 走直连。

## 相关依赖

> 依赖安装参考：<https://github.com/zfl9/ss-tproxy/wiki/安装依赖>

基础依赖：

- `bash`：脚本必须用 bash 执行，主要是因为用了 shell 数组等语法特性。
- `iptables`：用于配置 IPv4 透明代理规则，仅在启用 IPv4 透明代理时需要。
- `ip6tables`：用于配置 IPv6 透明代理规则，仅在启用 IPv6 透明代理时需要。
- `ipset`：用于存储黑名单/白名单的 IP，使 iptables 规则与 dns 组件实现联动。

TPROXY 相关：

- `xt_TPROXY`：TPROXY 内核模块，涉及到 TPROXY 规则时需要此依赖（如 UDP）。
- `iproute2`：用于配置策略路由，完成 TPROXY 操作，与 xt_TPROXY 是互相配套的。

默认 DNS 方案：

- `dnsmasq`：基础 DNS 服务，对于 global/gfwlist 模式，需要支持 `--ipset` 选项。
- `chinadns-ng`：用于 chnroute 模式，v4.7 开始，也可用于 gfwlist 模式，提升性能。
- `dns2tcp`：用于 tcponly 模式，将 DNS 查询从 UDP 转为 TCP，注意是 [zfl9/dns2tcp](https://github.com/zfl9/dns2tcp)。

> 使用自定义 DNS 方案时，不需要上述 DNS 依赖。

其他依赖：

- `curl`：用于更新 gfwlist.txt、chnlist.txt、chnroute.txt，需要支持 https。

如果某些模式基本不用，那对应的依赖也不用管。比如，不打算使用 IPv6 透明代理，则无需关心 ip6tables；不打算使用 chnroute 模式，则无需关心 chinadns-ng。脚本会检查当前配置所需的依赖，根据提示安装缺少的依赖即可。

## 获取脚本

```bash
git clone https://github.com/zfl9/ss-tproxy
cd ss-tproxy
chmod +x ss-tproxy
```

## 安装脚本

> 请确保当前用户有权限读写以下目录，如没有，请先运行`sudo su`进入超级用户(root)。

- install 命令可用

```bash
install ss-tproxy /usr/local/bin
install -d /etc/ss-tproxy
install -m 644 *.conf *.txt *.ext /etc/ss-tproxy
install -m 644 ss-tproxy.service /etc/systemd/system # 可选，安装 service 文件
```

- install 命令不可用

```bash
cp -af ss-tproxy /usr/local/bin
mkdir -p /etc/ss-tproxy
cp -af *.conf *.txt *.ext /etc/ss-tproxy
cp -af ss-tproxy.service /etc/systemd/system # 可选，安装 service 文件
```

## 卸载脚本

```bash
# 停止脚本 (v4.7版本之前)
ss-tproxy stop
ss-tproxy flush-postrule
ss-tproxy delete-gfwlist

# 停止脚本 (v4.7版本开始)
ss-tproxy stop
ss-tproxy flush-stoprule

# 删除文件
rm -fr /usr/local/bin/ss-tproxy # 删除脚本
rm -fr /etc/ss-tproxy # 删除配置(做好备份)
rm -fr /etc/systemd/system/ss-tproxy.service # service文件
```

## 升级脚本

脚本目前没有自我更新能力，只能卸载后重新安装，也许后续会支持。

不同版本的配置文件、数据文件，不保证兼容，避免背上不必要的历史包袱。

## 文件列表

- `ss-tproxy`：shell 脚本，欢迎各位大佬一起来改进这个脚本。
- `ss-tproxy.conf`：配置文件，本质是 shell 脚本，修改需重启生效。
- `ss-tproxy.service`：systemd 服务文件，用于 ss-tproxy 开机自启。
- `chnlist.txt`：用于 chnroute 模式，大陆域名列表，别去手动修改。
- `chnroute.txt`：用于 chnroute 模式，大陆v4地址段，别去手动修改。
- `chnroute6.txt`：用于 chnroute 模式，大陆v6地址段，别去手动修改。
- `gfwlist.txt`：用于 gfwlist/chnroute 模式，gfw域名列表，别去手动修改。
- `gfwlist.ext`：用于 gfwlist/chnroute 模式，扩展黑名单，可配置，重启生效。
- `ignlist.ext`：用于 global/chnroute 模式，扩展白名单，可配置，重启生效。

> ss-tproxy 只是一个 shell 脚本，并不是常驻后台的服务，因此所有的修改都需要 restart 来生效。

## 配置说明

> 注意，配置文件在 /etc/ss-tproxy/ 目录，不是 git clone 下来的目录！

配置项有点多，但通常只需修改 ss-tproxy.conf 前面的少数配置项（开头至`proxy`配置段）

<details><summary>注释</summary>
    
井号开头的行为注释行，配置文件本质上是一个 shell 脚本，对于同名变量或函数，后定义的会覆盖先定义的。
    
</details>

<details><summary>mode</summary>

分流模式，默认为 chnroute 模式，可根据需要修改为 global/gfwlist 模式。

</details>

<details><summary>ipv4、ipv6</summary>

- 启用 IPv4/IPv6 透明代理，你需要确保本机代理进程能正确处理 IPv4/IPv6 相关数据包，脚本不检查它
- 启用 IPv6 透明代理应检查当前的 Linux 内核版本是否为 `v3.9.0+`，以及 ip6tables 的版本是否为 `v1.4.18+`

</details>

<details><summary>tproxy</summary>
    
- true 表示 tcp 和 udp 都使用 TPROXY，**纯 TPROXY 模式**。
- false 表示 tcp 使用 REDIRECT，udp 使用 TPROXY，**混合模式**。

列举一些常见的代理套件：

- ss/ssr/trojan：混和模式
- v2ray：两者都可，取决于配置
- ipt2socks：默认纯 TPROXY 模式
- hysteria：支持纯 TPROXY 模式
- trojan-go：只使用纯 TPROXY 模式
- ss-libev：3.3.5+ 支持纯 TPROXY 模式

> 此配置非常重要，配置不当将无法透明代理。

</details>

<details><summary>tcponly</summary>

- true 表示仅代理 TCP 流量
- false 表示代理 TCP 和 UDP 流量

> 某些机场、server 不支持 UDP，请注意判别。

</details>

<details><summary>selfonly</summary>

- true 表示仅代理 ss-tproxy 主机自身的流量
- false 表示代理 ss-tproxy 主机自身以及内网主机的流量

> 内网主机如果想走代理，必须将 **网关**、**DNS** 都指向 ss-tproxy 主机。

</details>

<details><summary>proxy_procgroup</summary>
    
- 可以填 gid，也可以填 name，建议用 name，脚本会自动帮你创建 group
- 所有代理进程都必须以此 group 身份运行（否则会产生死循环），脚本不检查它
- 此文档的所有示例，均使用`proxy`组，如非必要，请勿修改为其他 group，防止出错
 
</details>

<details><summary>proxy_tcpport、proxy_udpport</summary>
    
- `本机代理进程`的 **透明代理** 监听端口，前者为 TCP 端口，后者为 UDP 端口，通常情况下是相同的。
- 如果 UDP 不稳定，或无法使用 UDP，请使用 `tcponly` 模式，这种情况下，`proxy_udpport` 被忽略。
- 此端口必须支持 **透明代理** 传入(REDIRECT/TPROXY)，并且必须与 `tproxy` 配置保持一致，否则将出错。
 
</details>

<details><summary>proxy_startcmd、proxy_stopcmd</summary>
    
- 前者是启动`本机代理进程`的 shell 命令，后者是关闭`本机代理进程`的 shell 命令
- 这些命令不应执行过长时间，防止卡住脚本，长时间处于某种中间状态
- 具体命令例子，见 [代理软件配置](#代理软件配置)

如果需要切换代理节点，请直接操作相关代理进程，而不是修改 ss-tproxy.conf、`ss-tproxy restart`，因为这是一个重量级操作，没有必要反复操作 iptables 规则、重启 DNS 服务。

ss-tproxy 提供 proxy_startcmd/proxy_stopcmd 的目的，是为了“帮你”启动/关闭代理进程，并不是要完全接管它；因此，对于那些不涉及 iptables 规则、DNS 服务的操作（比如切换节点），请不要通过 ss-tproxy 进行。

如果觉得切换节点麻烦，可以使用那些支持 **自动切换节点** 的代理套件，比如 clash，又比如套上 haproxy，或者用脚本封装节点切换操作，总之，请尽情发挥你的想象力。

ss-tproxy 要求代理进程不参与 ip 分流、dns 分流/解析，专心实现 TCP/UDP 全局透明代理即可，脚本已经帮你设置好了 iptables 分流规则，iptables 分流比代理进程的“用户空间”分流更快，性能开销更小，也更加彻底。

</details>

<details><summary>dns_custom</summary>

给高级用户用的，用于自定义 DNS 方案，具体见 ss-tproxy.conf、ss-tproxy 脚本、[wiki/DNS方案](https://github.com/zfl9/ss-tproxy/wiki/DNS方案)。

</details>

<details><summary>dns_procgroup</summary>

- 可以填 gid，也可以填 name，建议用 name，脚本会自动帮你创建 group
- 所有 DNS 进程都必须以此 group 身份运行（否则会产生死循环），脚本不检查它
- 默认是`proxy_dns`，使用内置 DNS 方案时，无需关心此配置，脚本会自动帮你处理

</details>

<details><summary>dns_mainport</summary>
    
- DNS 的请求入口（UDP 监听端口），脚本会自动将相关 DNS 请求重定向至此端口
- 对于内置 DNS 方案，该端口是 dnsmasq 的监听端口，如果与其他进程有冲突，请修改
 
</details>

<details><summary>chinadns_for_gfwlist</summary>

在 chinadns-ng 已安装的情况下，如果使用 mode=gfwlist 分流，chinadns-ng 将接管 DNS 分流操作，这是由于 dnsmasq 不适合配置大量 server、ipset 记录，会拉低 DNS 解析性能，所以使用 chinadns-ng 来避免该问题。

</details>

<details><summary>chinadns_chnlist_first</summary>

该选项只作用于 mode=chnroute，用于设置 chinadns-ng 的 `--chnlist-first` 选项。该选项只影响那些 **同时位于黑白名单** 的域名模式，具体解释可以参见 chinadns-ng 的 README 文档。

</details>

<details><summary>ipts_set_snat</summary>

selfonly=false 时有效，设置 IPv4 的 MASQUERADE 规则，有两种情况需要将其设置为 true：

- ss-tproxy 部署在出口路由位置，即至少两张网卡，一张连内网，一张连公网，需要源地址转换。
- 黑名单正常访问，但白名单无法访问，如百度，请设置为 true，这种情况通常与路由器设置有关。

此规则在 ss-tproxy stop 后仍然有效，如果你想清空这些规则，请执行 `ss-tproxy flush-stoprule`。

</details>

<details><summary>ipts_set_snat6</summary>

selfonly=false 时有效，设置 IPv6 的 MASQUERADE 规则，需要设置的情况同 ipts_set_snat。

v4.6+ 版本的 IPv6 透明代理可以通过 GUA 公网地址进行，不需要额外配置。但如果希望其他主机也使用 ss-tproxy 主机的代理（网关和 DNS 都指向 ss-tproxy 主机），建议给相关主机配置 ULA 静态私有地址，也就是组建一个 IPv6 内网，避免公网 IP 经常变动带来的麻烦。这种情况下，你需要将此配置设为 true。

</details>

<details><summary>ipts_reddns_onstop、ipts_reddns6_onstop</summary>
 
此配置仅在 selfonly=false 时有效；前者用于 IPv4，后者用于 IPv6；必须指定端口号。

ss-tproxy stop 后，是否将内网主机发往 ss-tproxy 主机的 DNS 请求重定向至给定的 DNS，为什么要这么做？因为其它内网主机的 DNS 已经指向了 ss-tproxy 主机，但现在 ss-tproxy 已经关闭了，附带的 DNS 服务自然也被一同关闭，所以这些内网主机会因为无法解析 DNS 而无法上网。

设置该选项后，ss-tproxy 会设置一些 iptables 规则，重定向至指定的 DNS，确保内网主机可以正常上网。这些规则在执行 start 时会被自动移除，如果在 stop 状态下需要手动移除规则，请执行 `ss-tproxy flush-stoprule`。

如果 ss-tproxy 主机上有可用的 DNS 服务，请设置为空串（留空）。
 
</details>

<details><summary>ipts_proxy_dst_port</summary>
 
要代理 **黑名单** 的哪些端口，留空表示全部，等价于 `1:65535`。允许指定多个范围，逗号隔开即可。

如果觉得端口范围太大，可以设置为 `1:1023,8080`；此时，只有当我们访问黑名单的 1~1023 和 8080 端口时才会走代理，访问其它端口不走代理，因此可以利用此选项来放行 BT、PT 流量，因为这些流量的目的端口通常在 1024 以上。

修改此选项需要足够小心，配置不当会导致某些软件无法走代理，因为它们访问的目标端口可能不在你指定的范围内；因此将此选项留空，可能是最保险的一种做法，防止出现漏网之鱼。
 
</details>

<details><summary>ipts_drop_quic</summary>

丢弃发往 **黑名单** 的 QUIC 流量（目标端口为 UDP/443），黑名单是指“分流”时，被判定为要走代理的地址。注意：本机代理进程传出的流量，不会受到此配置的影响。目前有如下取值：

- 留空：不丢弃 QUIC，主要用于兼容旧版本行为。
- tcponly：tcponly='true' 时，丢弃 QUIC，见 [#237](https://github.com/zfl9/ss-tproxy/issues/237) issue。
- always：总是丢弃 QUIC；如果代理的 UDP 体验差，建议丢弃。

比如 YouTube、ChatGPT 就默认启用 QUIC，如果油管测速比较低、ChatGPT 无法使用，可以尝试禁用 QUIC。

</details>

<details><summary>opts_ss_netstat</summary>

告诉 ss-tproxy，使用 ss 还是 netstat 命令进行端口检测，目前检测`本机代理进程`是否正常运行的方式是直接检测其是否已监听对应的端口，虽然这种方式有时并不准确，但似乎也没有其它更好的便携方法来做这个事情。

- `auto`：优先考虑 ss，没有 ss 时，使用 netstat
- `ss`：使用 ss，ss 由 iproute2 提供
- `netstat`：使用 netstat

</details>

## 代理软件配置

<details><summary>ss-libev</summary>
 
ss 配置文件 /etc/ss.json，与常规配置相同，无特别之处。

```javascript
{
    "server": "服务器地址",
    "server_port": 服务器端口,
    "local_address": "127.0.0.1",
    "local_port": 60080,
    "method": "加密方式",
    "password": "用户密码",
    "no_delay": true,
    "fast_open": true,
    "reuse_port": true
}
```

配置 ss-tproxy.conf，填写启动和停止命令：

```bash
# 这里只介绍 v4.7+ 版本的配置

proxy_startcmd='start_ss'
proxy_stopcmd='stop_ss'

start_ss() {
    # 设置 setgid 权限位 (只需执行一次)
    set_proxy_group ss-redir

    (ss-redir -c /etc/ss.json -u </dev/null &>>/var/log/ss-redir.log &)

    # -v 表示记录详细日志
    # (ss-redir -c /etc/ss.json -u -v </dev/null &>>/var/log/ss-redir.log &)
}

stop_ss() {
    kill -9 $(pidof ss-redir) &>/dev/null
}
```

</details>

<details><summary>ssr-libev</summary>

ssr 配置文件 /etc/ssr.json，与常规配置相同，无特别之处。

```javascript
{
    "server": "服务器地址",
    "server_port": 服务器端口,
    "local_address": "127.0.0.1",
    "local_port": 60080,
    "method": "加密方式",
    "password": "用户密码",
    "protocol": "origin",
    "protocol_param": "",
    "obfs": "plain",
    "obfs_param": ""
}
```

配置 ss-tproxy.conf，填写启动和停止命令：

```bash
# 这里只介绍 v4.7+ 版本的配置

proxy_startcmd='start_ssr'
proxy_stopcmd='stop_ssr'

start_ssr() {
    # 设置 setgid 权限位 (只需执行一次)
    set_proxy_group ssr-redir

    (ssr-redir -c /etc/ssr.json -u </dev/null &>>/var/log/ssr-redir.log &)

    # -v 表示记录详细日志
    # (ssr-redir -c /etc/ssr.json -u -v </dev/null &>>/var/log/ssr-redir.log &)
}

stop_ssr() {
    kill -9 $(pidof ssr-redir) &>/dev/null
}
```

</details>

<details><summary>v2ray</summary>

v2ray 配置文件 /etc/v2ray.json，在原有配置上，添加 dokodemo-door 入站协议即可。

- 由于 v2ray 配置复杂，在报告问题之前，请检查配置是否有问题，这里不解答 v2ray 配置问题
- **原则上不建议在 v2ray 上配置任何分流或路由规则**，脚本会为你做这些事，请尽量保持配置简单
- 据反馈，`dokodemo-door` 的 UDP 存在断流 bug，可尝试使用 ipt2socks 配合 socks5 入站协议缓解

```javascript
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "info" // 调试时请改为 debug
  },

  "inbounds": [
    {
      "protocol": "dokodemo-door",
      "listen": "127.0.0.1",
      "port": 60080, // 必须与proxy_tcpport/proxy_udpport保持一致
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "sockopt": {
          // 若有改动，请同步修改 ss-tproxy.conf 的 tproxy 配置
          // "tproxy": "tproxy" // tproxy + tproxy 模式 (纯tproxy)
          "tproxy": "redirect" // redirect + tproxy 模式 (redirect)
        }
      }
    }
  ],

  "outbounds": [
    {
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "服务器地址",
            "port": 服务器端口,
            "method": "加密方式",
            "password": "用户密码"
          }
        ]
      }
    }
  ]
}
```

配置 ss-tproxy.conf，填写启动和停止命令：

```bash
# 这里只介绍 v4.7+ 版本的配置

proxy_startcmd='start_v2ray'
proxy_stopcmd='stop_v2ray'

start_v2ray() {
    # 设置 setgid 权限位 (只需执行一次)
    set_proxy_group v2ray
    set_proxy_group v2ctl

    (v2ray -config /etc/v2ray.json </dev/null &>/dev/null &)
}

stop_v2ray() {
    kill -9 $(pidof v2ray) $(pidof v2ctl) &>/dev/null
}
```

</details>

<details><summary>trojan(socks5)</summary>

- 如果手上只有 socks5 代理，可以将 [ipt2socks](https://github.com/zfl9/ipt2socks) 作为其前端，提供透明代理传入
- 以 trojan 为例，trojan 原生不支持 udp 透明代理传入，所以配合 ipt2socks 来实现
- 假设 trojan 配置文件为 /etc/trojan.json，注意 run_type 为 client，也就是 socks5 传入

```javascript
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "服务器地址",
    "remote_port": 服务器端口,
    "password": [
        "用户密码"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
```

配置 ss-tproxy.conf，填写启动和停止命令：

```bash
# 这里只介绍 v4.7+ 版本的配置

tproxy='true' # ipt2socks默认为tproxy模式

proxy_startcmd='start_trojan'
proxy_stopcmd='stop_trojan'

start_trojan() {
    # 设置 setgid 权限位 (只需执行一次)
    set_proxy_group trojan
    set_proxy_group ipt2socks

    (trojan -c /etc/trojan.json </dev/null &>>/var/log/trojan.log &)
    (ipt2socks </dev/null &>>/var/log/ipt2socks.log &)
}

stop_trojan() {
    kill -9 $(pidof trojan) $(pidof ipt2socks) &>/dev/null
}
```

</details>

<details><summary>hysteria</summary>

hysteria 配置文件 /etc/hysteria.json，这里使用 **纯 TPROXY 模式**：

```json
{
  "server": "example.com:36712",
  "obfs": "8ZuA2Zpqhuk8yakXvMjDqEXBwY",
  "up_mbps": 10,
  "down_mbps": 50,
  "retry": -1,
  "retry_interval": 1,
  "tproxy_tcp": {
    "listen": "127.0.0.1:60080",
    "timeout": 300
  },
  "tproxy_udp": {
    "listen": "127.0.0.1:60080",
    "timeout": 300
  }
}
```

配置 ss-tproxy.conf，填写启动和停止命令：

```bash
# 这里只介绍 v4.7+ 版本的配置

tproxy='true' # 纯tproxy模式

proxy_startcmd='start_hy'
proxy_stopcmd='stop_hy'

start_hy() {
    # 设置 setgid 权限位 (只需执行一次)
    set_proxy_group hysteria

    (hysteria -c /etc/hysteria.json </dev/null &>>/var/log/hysteria.log &)
}

stop_hy() {
    kill -9 $(pidof hysteria) &>/dev/null
}
```

</details>

<details><summary>naive(socks5)</summary>

- naive 不支持 UDP 代理，必须使用 tcponly='true' 模式
- 仍然以 ipt2socks 为例，配合 naive 的 socks5 传入协议

naive 配置文件：/etc/naive.json：

```javascript
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://用户:密码@naive服务器域名"
}
```

配置 ss-tproxy.conf，填写启动和停止命令：

```bash
# 这里只介绍 v4.7+ 版本的配置

tproxy='true' # ipt2socks默认为tproxy模式
tcponly='true' # naive不支持udp代理

proxy_startcmd='start_naive'
proxy_stopcmd='stop_naive'

start_naive() {
    # 设置 setgid 权限位 (只需执行一次)
    set_proxy_group naive
    set_proxy_group ipt2socks

    (naive /etc/naive.json </dev/null &>>/var/log/naive.log &)
    (ipt2socks </dev/null &>>/var/log/ipt2socks.log &)
}

stop_naive() {
    kill -9 $(pidof naive) $(pidof ipt2socks) &>/dev/null
}
```

</details>

---

再次重申，如果只是切换节点/代理，请不要通过修改 ss-tproxy.conf、重启 ss-tproxy 的方式进行，请直接操作相关代理进程。举个例子，对于 ss-redir，就是先把原来的 ss-redir 进程杀死，然后启动新的 ss-redir 进程。当然，你可以用脚本或者你喜欢的任意方式，来封装节点切换操作，或者使用 clash 这种支持 **自动切换/选择节点** 的代理客户端。

## 脚本命令行选项

- `ss-tproxy help`：查看帮助信息
- `ss-tproxy version`：查看版本号
- `ss-tproxy start`：启动透明代理
- `ss-tproxy stop`：关闭透明代理
- `ss-tproxy restart`：重启透明代理
- `ss-tproxy status`：查看代理状态
- `ss-tproxy show-iptables`：查看当前的 iptables 规则
- `ss-tproxy flush-stoprule`：清空 stop 状态下的 iptables 规则
- `ss-tproxy flush-dnscache`：清空 DNS 查询缓存
- `ss-tproxy update-gfwlist`：更新 gfwlist.txt，restart 后生效
- `ss-tproxy update-chnlist`：更新 chnlist.txt，restart 后生效
- `ss-tproxy update-chnroute`：更新 chnroute*.txt，restart 后生效
- `ss-tproxy set-proxy-group <可执行文件>`：设置所属 group、setgid 权限位
- `ss-tproxy set-dns-group <可执行文件>`：设置所属 group、setgid 权限位

---

此外，可以在命令行的任意位置，指定以下选项：

- `-x`：输出调试信息，比如脚本出错时，可用来定位是哪条命令
- `-d dir`：使用给定的工作目录，默认是 /etc/ss-tproxy
- `-c config`：使用给定的配置文件，默认是 ss-tproxy.conf
- `NAME=VALUE`：定义变量，可用来临时覆盖 ss-tproxy.conf 中的同名配置

---

ss-tproxy restart 后，可能会由于 DNS 缓存，导致无法代理，请尝试：

- 清空当前系统的 DNS 缓存：
  - Windows：打开 cmd，执行 `ipconfig /flushdns`
  - 手机：可以开关一下飞行模式，或者重连一下 WiFi
- 如果还不行，请重新打开当前应用程序，然后再试

---

如果要修改以下配置，请先 stop，再修改 ss-tproxy.conf，再 start。

- `proxy_stopcmd`
- `ipts_rt_tab`

对于 proxy_stopcmd，如果忘记遵循 **先 stop，后修改** 的顺序，也可以补救，那就是自己手动 kill 之前的代理进程。当然，你也可以在 proxy_stopcmd 中预先填写好所有可能要 kill 的代理进程，这样后续就不需要再修改了。

> 其他 ss-tproxy.conf 配置无需遵循上述约定，改完 restart 即可。

## 脚本开机自启

对于 `SysVinit` 发行版，直接在 `/etc/rc.d/rc.local` 开机脚本中加上 ss-tproxy 的启动命令即可：

```bash
/usr/local/bin/ss-tproxy start
```

对于 `Systemd` 发行版，将 ss-tproxy.service 文件放到 `/etc/systemd/system/ss-tproxy.service`，执行：

```bash
systemctl daemon-reload
systemctl enable ss-tproxy
```

> 不建议使用 `systemctl start|stop|restart ss-tproxy` 来操作 ss-tproxy，此服务文件应仅作开机自启用。

如果遇到开机自启失败的问题，可以看下这个 wiki：<https://github.com/zfl9/ss-tproxy/wiki/开机自启>

## IPv6 透明代理

对于 v4.6+ 版本，设置 `ipv6` 选项即可使用 IPv6 透明代理，使用方法同 IPv4 透明代理。但如果想让其他主机也接入 ss-tproxy 的透明代理，建议给相关主机配置 ULA 静态私有地址，也就是组建一个局域网，这样在给他们设置网关和 DNS 时，就不怕公网 IP 经常变动了。在这种情况下，你需要启用 ss-tproxy.conf 的 ipts_set_snat6 选项。

## 更多信息请参见 wiki

- <https://github.com/zfl9/ss-tproxy/wiki/安装依赖>
- <https://github.com/zfl9/ss-tproxy/wiki/故障排查>
- <https://github.com/zfl9/ss-tproxy/wiki/常见问题>
- <https://github.com/zfl9/ss-tproxy/wiki/钩子函数>
- <https://github.com/zfl9/ss-tproxy/wiki/内网限速>
- <https://github.com/zfl9/ss-tproxy/wiki/开机自启>
- <https://github.com/zfl9/ss-tproxy/wiki/DNS方案>
