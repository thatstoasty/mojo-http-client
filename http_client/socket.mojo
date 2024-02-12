from .external.libc import (
    socket,
    connect,
    close,
    recv,
    send,
    shutdown,
    inet_pton,
    inet_ntoa,
    inet_ntop,
    to_char_ptr,
    htons,
    strlen,
    AF_INET,
    SOCK_STREAM,
    SHUT_RDWR,
    sockaddr,
    sockaddr_in,
    c_void,
    c_uint,
    c_char,
    addrinfo,
    AI_PASSIVE,
    getaddrinfo,
    gai_strerror,
    c_charptr_to_string,
    c_int,
    # SOL_SOCKET,
    # SO_REUSEADDR,
    # bind,
    # listen,
    # accept,
    # setsockopt,
    # socklen_t,
)
from memory.unsafe import bitcast


fn get_ip_address(host: String):
    # let ip_addr = "127.0.0.1"
    # let port = 8083

    var servinfo = Pointer[addrinfo]().alloc(1)
    servinfo.store(addrinfo())

    var hints = addrinfo()
    hints.ai_family = AF_INET
    hints.ai_socktype = SOCK_STREAM
    hints.ai_flags = AI_PASSIVE

    var host_ptr = to_char_ptr(host)

    let status = getaddrinfo(
        host_ptr,
        Pointer[UInt8](),
        Pointer.address_of(hints),
        Pointer.address_of(servinfo),
    )
    print(status)
    if status != 0:
        print("getaddrinfo error")
        let msg_ptr = gai_strerror(c_int(status))
        _ = external_call["printf", c_int, Pointer[c_char], Pointer[c_char]](
            to_char_ptr("gai_strerror: %s"), msg_ptr
        )
        let msg = c_charptr_to_string(msg_ptr)
        print("getaddrinfo satus: " + msg)

    var server_info = servinfo.load()

    # Cast sockaddr to sockaddr_in to be used in inet_ntop to get the IP address
    # TODO: I'm supposed to traverse the resultant linked list using ai_next, but the next pointer is null.
    # var si = servinfo
    # var sa = server_info.ai_addr
    # while si and not sa:
    #     print("pointer is null")
    #     si = server_info.ai_next

    #     if not si:
    #         print("si is null")
    #         break
    #     print("moved to next")
    #     sa = si.load().ai_addr

    # if servinfo:
    #     var addr_in = bitcast[sockaddr_in](server_info.ai_addr)
    #     if not addr_in:
    #         print("addr_in is null")
    #         return

    print(server_info.ai_addrlen)
    if server_info.ai_addr:
        print("ai_addr is not null")
    # let buf = Pointer[UInt8]().alloc(1024)
    # var ip_address_ptr = inet_ntoa(a)
    # print(ip_address_ptr.load())
    # inet_ntop(AF_INET, a.s_addr, buf, 1024)
    # server_info.ai_next

    # print(server_info.ai_family)

    # for i in range(len(addr)):
    #     print(addr[i])

    # print()


@value
struct Socket():
    var sockfd: Int32
    var address_family: Int
    var socket_type: UInt8
    var _closed: Bool

    fn __init__(inout self, address_family: Int = AF_INET, socket_type: UInt8 = SOCK_STREAM):
        self.address_family = address_family
        self.socket_type = socket_type
        let sockfd = socket(address_family, SOCK_STREAM, 0)
        if sockfd == -1:
            print("Socket creation error")
        self.sockfd = sockfd
        self._closed = False
        
    
    fn __enter__(self) -> Self:
        return self
    
    # fn __exit__(inout self):
    #     if not self._closed:
    #         self.close()

    # fn accept(self):
    #     pass
    
    # fn bind(self):
    #     pass
    
    # fn file_no(self) -> Int32:
    #     return self.sockfd
    
    # fn get_sock_name(self):
    #     pass
    
    # fn get_peer_name(self):
    #     pass
    
    # fn get_sock_opt(self):
    #     pass
    
    # fn set_sock_opt(self):
        pass
                
    fn connect(self, host: String, port: Int):
        let ip_addr = host
        let address_family = AF_INET
        let bin_port = htons(UInt16(port))

        let ip_buf = Pointer[c_void].alloc(4)
        let conv_status = inet_pton(address_family, to_char_ptr(ip_addr), ip_buf)
        let raw_ip = ip_buf.bitcast[c_uint]().load()

        var ai = sockaddr_in(address_family, bin_port, raw_ip, StaticTuple[8, c_char]())
        let ai_ptr = Pointer[sockaddr_in].address_of(ai).bitcast[sockaddr]()

        if connect(self.sockfd, ai_ptr, sizeof[sockaddr_in]()) == -1:
            self.shutdown()
            return  # Ensure to exit if connection fails
    
    fn send(self, header: String):
        let header_ptr = to_char_ptr(header)
    
        let bytes_sent = send(self.sockfd, header_ptr, strlen(header_ptr), 0)
        if bytes_sent == -1:
            print("Failed to send message")
    
    fn receive(self, bytes_to_receive: Int = 1024) -> String:
        let buf_size = bytes_to_receive
        let buf = Pointer[UInt8]().alloc(buf_size)
        let bytes_recv = recv(self.sockfd, buf, buf_size, 0)
        if bytes_recv == -1:
            print("Failed to receive message")
            return ""

        return String(buf.bitcast[Int8](), bytes_recv)
    
    fn shutdown(self):
        _ = shutdown(self.sockfd, SHUT_RDWR)
    
    fn close(inout self):
        self.shutdown()
        let close_status = close(self.sockfd)
        if close_status == -1:
            print("Failed to close socket")
            return

        self._closed = True
