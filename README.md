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
// TODO
