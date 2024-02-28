from memory.unsafe import bitcast
from tensor import Tensor
from .c.types import (
    c_void,
    c_uint,
    c_char,
    c_int,
)
from .c.net import (
    sockaddr,
    sockaddr_in,
    addrinfo,
    socklen_t,
    socket,
    connect,
    recv,
    send,
    shutdown,
    inet_pton,
    inet_ntoa,
    inet_ntop,
    to_char_ptr,
    htons,
    ntohs,
    strlen,
    getaddrinfo,
    gai_strerror,
    c_charptr_to_string,
    bind,
    listen,
    accept,
    setsockopt,
    getsockopt,
    getsockname,
    getpeername,
    c_charptr_to_string,
    AF_INET,
    SOCK_STREAM,
    SHUT_RDWR,
    AI_PASSIVE,
    SOL_SOCKET,
    SO_REUSEADDR,
)
from .c.file import close
from .connection import SysConnection, TCPAddr


fn get_addr_info(host: String) raises -> addrinfo:
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
    if status != 0:
        print("getaddrinfo failed to execute with status:", status)
        let msg_ptr = gai_strerror(c_int(status))
        _ = external_call["printf", c_int, Pointer[c_char], Pointer[c_char]](
            to_char_ptr("gai_strerror: %s"), msg_ptr
        )
        let msg = c_charptr_to_string(msg_ptr)
        print("getaddrinfo error message: ", msg)

    if not servinfo:
        print("servinfo is null")
        raise Error("Failed to get address info. Pointer to addrinfo is null.")

    return servinfo.load()


fn get_ip_address(host: String) raises -> String:
    """Get the IP address of a host."""
    # Call getaddrinfo to get the IP address of the host.
    let addrinfo = get_addr_info(host)
    let ai_addr = addrinfo.ai_addr
    if not ai_addr:
        print("ai_addr is null")
        raise Error(
            "Failed to get IP address. getaddrinfo was called successfully, but ai_addr"
            " is null."
        )

    # Cast sockaddr struct to sockaddr_in struct and convert the binary IP to a string using inet_ntop.
    let addr_in = ai_addr.bitcast[sockaddr_in]().load()

    return convert_binary_ip_to_string(
        addr_in.sin_addr.s_addr, addrinfo.ai_family, addrinfo.ai_addrlen
    )


fn convert_port_to_binary(port: Int) -> UInt16:
    return htons(UInt16(port))


fn convert_binary_port_to_int(port: UInt16) -> Int:
    return int(ntohs(port))


fn convert_ip_to_binary(ip_address: String, address_family: Int) -> UInt32:
    let ip_buffer = Pointer[c_void].alloc(4)
    let status = inet_pton(address_family, to_char_ptr(ip_address), ip_buffer)
    if status == -1:
        print("Failed to convert IP address to binary")

    return ip_buffer.bitcast[c_uint]().load()


fn convert_binary_ip_to_string(
    owned ip_address: UInt32, address_family: Int32, address_length: UInt32
) -> String:
    """Convert a binary IP address to a string by calling inet_ntop.

    Args:
        ip_address: UInt32 - The binary IP address.
        address_family: Int32 - The address family of the IP address.
        address_length: UInt32 - The length of the address.

    Returns:
        String - The IP address as a string.
    """
    var ip_buffer = Pointer[c_void].alloc(16)
    var ip_address_ptr = Pointer.address_of(ip_address).bitcast[c_void]()
    _ = inet_ntop(address_family, ip_address_ptr, ip_buffer, 16)

    var string_buf = ip_buffer.bitcast[Int8]()
    return String(string_buf, 16)


fn build_sockaddr_pointer(
    ip_address: String, port: Int, address_family: Int
) -> Pointer[sockaddr]:
    """Build a sockaddr pointer from an IP address and port number.
    https://learn.microsoft.com/en-us/windows/win32/winsock/sockaddr-2
    https://learn.microsoft.com/en-us/windows/win32/api/ws2def/ns-ws2def-sockaddr_in.
    """
    let bin_port = convert_port_to_binary(port)
    let bin_ip = convert_ip_to_binary(ip_address, address_family)

    var ai = sockaddr_in(address_family, bin_port, bin_ip, StaticTuple[8, c_char]())
    return Pointer[sockaddr_in].address_of(ai).bitcast[sockaddr]()


@value
struct Socket:
    var sockfd: Int32
    var address_family: Int
    var socket_type: UInt8
    var protocol: UInt8
    var _closed: Bool

    fn __init__(
        inout self,
        address_family: Int = AF_INET,
        socket_type: UInt8 = SOCK_STREAM,
        protocol: UInt8 = 0,
    ):
        self.address_family = address_family
        self.socket_type = socket_type
        self.protocol = protocol

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

    @always_inline
    fn accept(self) raises -> SysConnection:
        let their_addr_ptr = Pointer[sockaddr].alloc(1)
        var sin_size = socklen_t(sizeof[socklen_t]())
        let new_sockfd = accept(
            self.sockfd, their_addr_ptr, Pointer[socklen_t].address_of(sin_size)
        )
        if new_sockfd == -1:
            print("Failed to accept connection")
        # TODO: pass raddr to connection
        return SysConnection(TCPAddr("", 0), TCPAddr("", 0), new_sockfd)

    @always_inline
    fn bind(self, address: String, port: Int):
        let sockaddr_pointer = build_sockaddr_pointer(
            address, port, self.address_family
        )

        if bind(self.sockfd, sockaddr_pointer, sizeof[sockaddr_in]()) == -1:
            _ = shutdown(self.sockfd, SHUT_RDWR)
            print("Binding socket failed. Wait a few seconds and try again?")

    @always_inline
    fn file_no(self) -> Int32:
        return self.sockfd

    @always_inline
    fn get_sock_name(self) raises -> String:
        if self._closed:
            raise Error("Socket is closed")
        
        # TODO: Add check to see if the socket is bound and error if not.

        let socket_address_pointer = Pointer[sockaddr].alloc(1)
        var sin_size = socklen_t(sizeof[socklen_t]())
        let status = getsockname(
            self.sockfd, socket_address_pointer, Pointer[socklen_t].address_of(sin_size)
        )
        if status == -1:
            raise Error("Failed to get socket name")
        let addr_in = socket_address_pointer.bitcast[sockaddr_in]().load()

        return convert_binary_ip_to_string(
            addr_in.sin_addr.s_addr, AF_INET, 16
        )

    fn get_peer_name(self) raises -> String:
        if self._closed:
            raise Error("Socket is closed.")
        
        # TODO: Add check to see if the socket is bound and error if not.

        let socket_address_pointer = Pointer[sockaddr].alloc(1)
        var sin_size = socklen_t(sizeof[socklen_t]())
        let status = getpeername(
            self.sockfd, socket_address_pointer, Pointer[socklen_t].address_of(sin_size)
        )
        if status == -1:
            raise Error("Failed to get the address of the peer connected to the socket.")
        let addr_in = socket_address_pointer.bitcast[sockaddr_in]().load()

        return convert_binary_ip_to_string(
            addr_in.sin_addr.s_addr, AF_INET, 16
        )

    fn get_sock_opt(self, option_name: Int) raises -> Int:
        let option_value_pointer = Pointer[c_void].alloc(1)
        var option_len = socklen_t(sizeof[socklen_t]())
        var option_len_pointer = Pointer.address_of(option_len)
        let status = getsockopt(
            self.sockfd,
            SOL_SOCKET,
            option_name,
            option_value_pointer,
            option_len_pointer,
        )
        if status == -1:
            raise Error("getsockopt failed.")

        return option_value_pointer.bitcast[Int]().load()

    fn set_sock_opt(self, option_name: Int, owned option_value: UInt8 = 1) raises:
        """ """
        var option_value_pointer = Pointer.address_of(option_value)
        let status = setsockopt(
            self.sockfd, SOL_SOCKET, option_name, option_value_pointer, sizeof[c_void]()
        )
        if status == -1:
            raise Error("setsockopt failed.")

    fn connect(self, address: String, port: Int):
        let sockaddr_pointer = build_sockaddr_pointer(
            address, port, self.address_family
        )

        if connect(self.sockfd, sockaddr_pointer, sizeof[sockaddr_in]()) == -1:
            self.shutdown()
            return  # Ensure exit if connection fails

    fn send(self, header: String):
        let header_ptr = to_char_ptr(header)

        let bytes_sent = send(self.sockfd, header_ptr, strlen(header_ptr), 0)
        if bytes_sent == -1:
            print("Failed to send message")

    fn receive(self, bytes_to_receive: Int = 4096) raises -> Tensor[DType.int8]:
        let buf = Pointer[UInt8]().alloc(bytes_to_receive)
        let bytes_recieved = recv(self.sockfd, buf, bytes_to_receive, 0)
        if bytes_recieved == -1:
            raise Error("Failed to receive message from socket.")

        # Cast the Pointer[UInt8] to a Pointer[DType.int8] and create a Tensor from the buffer.
        var buffer_pointer = DTypePointer[DType.int8](buf.bitcast[Int8]())
        var byte_stream = Tensor(buffer_pointer, bytes_recieved)
        return byte_stream

    fn shutdown(self):
        _ = shutdown(self.sockfd, SHUT_RDWR)

    fn close(inout self):
        self.shutdown()
        let close_status = close(self.sockfd)
        if close_status == -1:
            print("Failed to close socket")
            return

        self._closed = True
