# Linux TCP+UDP 透明代理
## 脚本简介
ss-tproxy 目前存在 3 个版本，分别为 v1、v2、v3。最初编写 ss-tproxy 脚本的目的很简单，就是为了透明代理 ss/ssr，这也是脚本名称的由来。在 v1 版本中，ss-tproxy 只实现了 chnroute 大陆地址分流模式，因为我这边的网络即使访问普通的国外网站也很慢，所以干脆将国外网站都走代理。随着 ss-tproxy 被 star 的数量越来越多，促使我编写了 v2 版本，v2 版本先后实现了 global、gfwlist、chnonly、chnroute 四种分流模式，并且合并了 [ss-tun2socks](https://github.com/zfl9/ss-tun2socks)，支持 ss/ssr/v2ray/socks5 的透明代理。因脚本结构问题，导致 v2 版本的代码行数达到了 1300+，使得脚本过于臃肿且难以维护，最终催生了现在的 v3 版本。

ss-tproxy v3 基本上可以认为是 ss-tproxy v2 的精简优化版，v3 版本去掉了很多不是那么常用的代理模式，如 tun2socks、tcponly，并提取出了 ss/ssr/v2ray 等代理软件的相同规则，所以 v3 版本目前只有两大代理模式：REDIRECT + TPROXY、TPROXY + TPROXY（纯 TPROXY 方式）。REDIRECT + TPROXY 是指 TCP 使用 REDIRECT 方式代理而 UDP 使用 TPROXY 方式代理；纯 TPROXY 方式则是指 TCP 和 UDP 均使用 TPROXY 方式代理。目前来说，ss-libev、ssr-libev、v2ray-core、redsocks2 均为 REDIRECT + TPROXY 组合方式，而最新版 v2ray-core 则支持纯 TPROXY 方式的代理。在 v3 中，究竟使用哪种组合是由 `proxy_tproxy='boolean_value'` 决定的，如果为 true 则为纯 TPROXY 模式，否则为 REDIRECT + TPROXY 模式（默认）。

v3 版本仍然实现了 global、gfwlist、chnonly、chnroute 四种分流模式；global 是指全部流量都走代理；gfwlist 是指 gfwlist.txt 与 gfwlist.ext 列表中的地址走代理，其余走直连；chnonly 本质与 gfwlist 没区别，只是 gfwlist.txt 与 gfwlist.ext 列表中的域名为大陆域名，所以 chnonly 是国外翻回国内的专用模式；chnroute 则是从 v1 版本开始就有的模式，chnroute 模式会放行特殊地址、国内地址的流量，然后其它的流量（发往国外的流量）都会走代理出去（默认）。

// TODO
