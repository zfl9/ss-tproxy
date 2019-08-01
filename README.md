# Linux 透明代理
## 什么是透明代理？
代理软件通常分为客户端（client）和服务端（server），server 运行在境外服务器（通常为 Linux 服务器），client 运行在本地主机（如 Windows、Linux、Android、iOS），client 与 server 之间通常使用 tcp 或 udp 协议进行数据通信。大多数 client 被实现为一个 http、socks5 代理服务器，一个软件如果想通过 client 来进行科学上网，需要使用 http、socks5 协议与 client 进行数据交互，这是绝大多数人的使用方式。这种代理方式，我们称之为 **正向代理**。所谓正向代理就是，一个软件如果想要使用 client 的代理服务，需要经过特定的设置，否则不会经过 client 的代理。

// TODO
