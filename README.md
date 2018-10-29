# Linux TCP+UDP 透明代理
## 脚本简介
ss-tproxy 目前存在 3 个版本，分别为 v1、v2、v3。最初编写 ss-tproxy 脚本的目的很简单，就是为了透明代理 ss/ssr，这也是脚本名称的由来。在 v1 版本中，ss-tproxy 只实现了 chnroute 大陆地址分流模式，因为我这边的网络即使访问普通的国外网站也很慢，所以干脆将国外网站都走代理。随着 ss-tproxy 被 star 的数量越来越多，促使我编写了 v2 版本，v2 版本先后实现了 global、gfwlist、chnonly、chnroute 四种分流模式，并且合并了 [ss-tun2socks](https://github.com/zfl9/ss-tun2socks)，支持 ss/ssr/v2ray/socks5 的透明代理。因脚本结构问题，导致 v2 的代码行数达到了 1300+，使得脚本过于臃肿且难以维护，最终催生了现在 v3 版本。

// TODO
