# ss-redir 透明代理
> TCPOnly 版本，如果你的 SS/SSR 不支持 UDP Relay，请使用此分支！

## 脚本依赖
- [脚本依赖 - 安装参考](https://www.zfl9.com/ss-redir.html#%E5%AE%89%E8%A3%85%E4%BE%9D%E8%B5%96)
- curl，获取大陆地址段列表
- ipset，保存大陆地址段列表
- haveged，防止系统出现熵过低的问题
- pdnsd，支持永久性缓存的 DNS 代理服务器
- chinadns，利用大陆地址段列表实现 DNS 分流
- dnsforwarder，本地 DNS 转发器，UDP 转 TCP 查询
- shadowsocks-libev，ss-redir，SS 透明代理（仅 TCP）
- shadowsocksr-libev，ssr-redir，SSR 透明代理（仅 TCP）
- 注：shadowsocks-libev、shadowsocksr-libev 二选一，可一并安装

## 端口占用
> 请检查是否有端口被占用，如果有请自行解决！

- pdnsd：0.0.0.0:53/udp
- chinadns：0.0.0.0:65353/udp
- dnsforwarder：0.0.0.0:60053/udp
- ss-redir：0.0.0.0:60080/tcp+udp（udp 其实不需要，懒得改了）

## 脚本用法
**获取**
- `git clone https://github.com/zfl9/ss-tproxy.git`

**安装**
- `cd ss-tproxy`
- `git checkout tcponly`
- `cp -af ss-tproxy /usr/local/bin/`
- `cp -af ss-switch /usr/local/bin/`
- `chown root:root /usr/local/bin/ss-tproxy /usr/local/bin/ss-switch`
- `chmod +x /usr/local/bin/ss-tproxy /usr/local/bin/ss-switch`
- `mkdir -m 0755 -p /etc/tproxy`
- `cp -af pdnsd.conf /etc/tproxy/`
- `cp -af chnroute.txt /etc/tproxy/`
- `cp -af chnroute.ipset /etc/tproxy/`
- `cp -af ss-tproxy.conf /etc/tproxy/`
- `cp -af dnsforwarder.conf /etc/tproxy/`
- `chown -R root:root /etc/tproxy`
- `chmod 0644 /etc/tproxy/*`

**配置**
- `vim /etc/tproxy/ss-tproxy.conf`，修改后重启 ss-tproxy 生效
- 修改开头的 `ss/ssr 配置`，具体的含义请参考注释（此段配置必须修改）
- 切换 ss/ssr 节点时请修改 ss-tproxy.conf，或使用 ss-switch 切换（`ss-switch -h` 查看帮助）
- `chinadns_upstream="114.114.114.114,127.0.0.1:60053"`：建议将 114.114.114.114 改为原网络下的 DNS
- `iptables_intranet=(192.168.0.0/16)`：如果内网网段不是 192.168/16，请修改（可以有多个，空格隔开）
- `dns_original=(114.114.114.114 119.29.29.29 180.76.76.76)`：建议修改为原网络下的 DNS（最多 3 个）

**自启**（Systemd）
- `cp -af ss-tproxy.service /etc/systemd/system/`
- `systemctl daemon-reload`
- `systemctl enable ss-tproxy.service`

**自启**（SysVinit）
- `touch /etc/rc.d/rc.local`
- `chmod +x /etc/rc.d/rc.local`
- `echo "/usr/local/bin/ss-tproxy start" >> /etc/rc.d/rc.local`

> 配置 ss-tproxy 开机自启后容易出现一个问题，那就是必须再次运行 `ss-tproxy restart` 后才能正常代理（这之前查看运行状态，可能看不出任何问题，都是 running 状态），这是因为 ss-tproxy 启动过早了，且 server_addr 为 Hostname，且没有将 server_addr 中的 Hostname 加入 /etc/hosts 文件而导致的。因为 ss-tproxy 启动时，网络还没准备好，此时根本无法解析这个 Hostname。要避免这个问题，可以采取一个非常简单的方法，那就是将 Hostname 加入到 /etc/hosts 中，如 Hostname 为 node.proxy.net，对应的 IP 为 11.22.33.44，则只需执行 `echo "11.22.33.44 node.proxy.net" >> /etc/hosts`。不过得注意个问题，那就是假如这个 IP 变了，别忘了修改 /etc/hosts 文件哦。命令行获取某个域名对应的 IP 地址的方法：`dig +short HOSTNAME`。

**用法**
- `ss-tproxy help`：查看帮助
- `ss-tproxy start`：启动代理
- `ss-tproxy stop`：关闭代理
- `ss-tproxy restart`：重启代理
- `ss-tproxy status`：运行状态
- `ss-tproxy current_ip`：查看当前 IP（一般为本地 IP）
- `ss-tproxy flush_dnsche`：清空 dns 缓存（pdnsd 的缓存）
- `ss-tproxy update_chnip`：更新大陆地址段列表（ipset、chinadns）

**日志**
> 如需详细日志，请打开 ss-tproxy.conf 中相关的 verbose 选项。

- pdnsd：`/var/log/pdnsd.log`
- chinadns：`/var/log/chinadns.log`
- dnsforwarder：`/var/log/dnsforwarder.log`
- ss-redir：`/var/log/ss-redir.log`

## 相关参考
- [pdnsd](http://members.home.nl/p.a.rombouts/pdnsd/index.html)
- [ChinaDNS](https://github.com/shadowsocks/ChinaDNS)
- [dnsforwarder](https://github.com/holmium/dnsforwarder)
- [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)
- [shadowsocksr-libev](https://github.com/shadowsocksr-backup/shadowsocksr-libev)
- [ss-tproxy 常见问题](https://www.zfl9.com/ss-redir.html#%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98)
