from .c.net import (
    c_void,
    c_int,
    c_uint,
    c_char,
    sockaddr,
    sockaddr_in,
    socklen_t,
    AF_INET,
    AF_INET6,
    SOCK_STREAM,
    SOL_SOCKET,
    SO_REUSEADDR,
    SHUT_RDWR,
    htons,
    inet_pton,
    to_char_ptr,
    socket,
    setsockopt,
    listen,
    accept,
    send,
    recv,
    bind,
    shutdown,
)
from .c.file import close


@value
struct NetworkType:
    var value: String

    alias empty = NetworkType("")
    alias tcp = NetworkType("tcp")
    alias tcp4 = NetworkType("tcp4")
    alias tcp6 = NetworkType("tcp6")
    alias udp = NetworkType("udp")
    alias udp4 = NetworkType("udp4")
    alias udp6 = NetworkType("udp6")
    alias ip = NetworkType("ip")
    alias ip4 = NetworkType("ip4")
    alias ip6 = NetworkType("ip6")
    alias unix = NetworkType("unix")


fn join_host_port(host: String, port: String) -> String:
    if host.find(":") != -1:  # must be IPv6 literal
        return "[" + host + "]:" + port
    return host + ":" + port


alias missingPortError = Error("missing port in address")
alias tooManyColonsError = Error("too many colons in address")
alias default_buffer_size = 4096
alias default_tcp_keep_alive = Int(15 * 1000 * 1000 * 1000)  # 15 seconds


struct HostPort:
    var host: String
    var port: String

    fn __init__(inout self, host: String, port: String):
        self.host = host
        self.port = port


fn split_host_port(hostport: String) raises -> HostPort:
    var host: String = ""
    var port: String = ""
    let colon_index = hostport.rfind(":")
    var j: Int = 0
    var k: Int = 0

    if colon_index == -1:
        raise missingPortError
    if hostport[0] == "[":
        let end_bracket_index = hostport.find("]")
        if end_bracket_index == -1:
            raise Error("missing ']' in address")
        if end_bracket_index + 1 == len(hostport):
            raise missingPortError
        elif end_bracket_index + 1 == colon_index:
            host = hostport[1:end_bracket_index]
            j = 1
            k = end_bracket_index + 1
        else:
            if hostport[end_bracket_index + 1] == ":":
                raise tooManyColonsError
            else:
                raise missingPortError
    else:
        host = hostport[:colon_index]
        if host.find(":") != -1:
            raise tooManyColonsError
    if hostport[j:].find("[") != -1:
        raise Error("unexpected '[' in address")
    if hostport[k:].find("]") != -1:
        raise Error("unexpected ']' in address")
    port = hostport[colon_index + 1 :]

    if port == "":
        raise missingPortError
    if host == "":
        raise Error("missing host")
    return HostPort(host, port)


@value
struct TCPAddr:
    var ip: String
    var port: Int
    var zone: String  # IPv6 addressing zone

    fn __init__(inout self):
        self.ip = String("127.0.0.1")
        self.port = 8000
        self.zone = ""

    fn __init__(inout self, ip: String, port: Int):
        self.ip = ip
        self.port = port
        self.zone = ""

    fn network(self) -> String:
        return NetworkType.tcp.value

    fn string(self) -> String:
        if self.zone != "":
            return join_host_port(String(self.ip) + "%" + self.zone, self.port)
        return join_host_port(self.ip, self.port)


fn resolve_internet_addr(network: String, address: String) raises -> TCPAddr:
    var host: String = ""
    var port: String = ""
    var portnum: Int = 0
    if (
        network == NetworkType.tcp.value
        or network == NetworkType.tcp4.value
        or network == NetworkType.tcp6.value
        or network == NetworkType.udp.value
        or network == NetworkType.udp4.value
        or network == NetworkType.udp6.value
    ):
        if address != "":
            let host_port = split_host_port(address)
            host = host_port.host
            port = host_port.port
            portnum = atol(port.__str__())
    elif (
        network == NetworkType.ip.value
        or network == NetworkType.ip4.value
        or network == NetworkType.ip6.value
    ):
        if address != "":
            host = address
    elif network == NetworkType.unix.value:
        raise Error("Unix addresses not supported yet")
    else:
        raise Error("unsupported network type: " + network)
    return TCPAddr(host, portnum)


@value
struct SysConnection:
    var fd: c_int
    var raddr: TCPAddr
    var laddr: TCPAddr

    fn __init__(inout self, laddr: String, raddr: String) raises:
        self.raddr = resolve_internet_addr(NetworkType.tcp4.value, raddr)
        self.laddr = resolve_internet_addr(NetworkType.tcp4.value, laddr)
        self.fd = socket(AF_INET, SOCK_STREAM, 0)

    fn __init__(inout self, laddr: TCPAddr, raddr: TCPAddr) raises:
        self.raddr = raddr
        self.laddr = laddr
        self.fd = socket(AF_INET, SOCK_STREAM, 0)

    fn __init__(inout self, laddr: TCPAddr, raddr: TCPAddr, fd: c_int) raises:
        self.raddr = raddr
        self.laddr = laddr
        self.fd = fd

    fn read(self, inout buf: DynamicVector[Int8]) raises -> Int:
        let new_buf = Pointer[UInt8]().alloc(default_buffer_size)
        let bytes_recv = recv(self.fd, new_buf, default_buffer_size, 0)
        if bytes_recv == -1:
            print("Failed to receive message")
        let bytes_str = String(new_buf.bitcast[Int8](), bytes_recv)
        buf = bytes_str._buffer
        return bytes_recv

    fn write(self, buf: DynamicVector[Int8]) raises -> Int:
        let msg = String(buf)
        if send(self.fd, to_char_ptr(msg).bitcast[c_void](), len(msg), 0) == -1:
            print("Failed to send response")
        return len(buf)

    fn close(self) raises:
        _ = shutdown(self.fd, SHUT_RDWR)
        let close_status = close(self.fd)
        if close_status == -1:
            print("Failed to close new_sockfd")

    fn local_addr(inout self) raises -> TCPAddr:
        return self.laddr

    fn remote_addr(self) raises -> TCPAddr:
        return self.raddr
