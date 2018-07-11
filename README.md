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

## 脚本用法
// TODO
