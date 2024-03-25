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
    SO_RCVTIMEO,
)
from .c.file import close
from external.gojo.builtins import Bytes, Result, WrappedError, copy
import external.gojo.io

alias Seconds = Int


fn get_addr_info(host: String) raises -> addrinfo:
    var servinfo = Pointer[addrinfo]().alloc(1)
    servinfo.store(addrinfo())

    var hints = addrinfo()
    hints.ai_family = AF_INET
    hints.ai_socktype = SOCK_STREAM
    hints.ai_flags = AI_PASSIVE

    var host_ptr = to_char_ptr(host)

    var status = getaddrinfo(
        host_ptr,
        Pointer[UInt8](),
        Pointer.address_of(hints),
        Pointer.address_of(servinfo),
    )
    if status != 0:
        print("getaddrinfo failed to execute with status:", status)
        var msg_ptr = gai_strerror(c_int(status))
        _ = external_call["printf", c_int, Pointer[c_char], Pointer[c_char]](
            to_char_ptr("gai_strerror: %s"), msg_ptr
        )
        var msg = c_charptr_to_string(msg_ptr)
        print("getaddrinfo error message: ", msg)

    if not servinfo:
        print("servinfo is null")
        raise Error("Failed to get address info. Pointer to addrinfo is null.")

    return servinfo.load()


fn get_ip_address(host: String) raises -> String:
    """Get the IP address of a host."""
    # Call getaddrinfo to get the IP address of the host.
    var addrinfo = get_addr_info(host)
    var ai_addr = addrinfo.ai_addr
    if not ai_addr:
        print("ai_addr is null")
        raise Error(
            "Failed to get IP address. getaddrinfo was called successfully, but ai_addr"
            " is null."
        )

    # Cast sockaddr struct to sockaddr_in struct and convert the binary IP to a string using inet_ntop.
    var addr_in = ai_addr.bitcast[sockaddr_in]().load()

    return convert_binary_ip_to_string(
        addr_in.sin_addr.s_addr, addrinfo.ai_family, addrinfo.ai_addrlen
    ).strip()


fn convert_port_to_binary(port: Int) -> UInt16:
    return htons(UInt16(port))


fn convert_binary_port_to_int(port: UInt16) -> Int:
    return int(ntohs(port))


fn convert_ip_to_binary(ip_address: String, address_family: Int) -> UInt32:
    var ip_buffer = Pointer[c_void].alloc(4)
    var status = inet_pton(address_family, to_char_ptr(ip_address), ip_buffer)
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
    var bin_port = convert_port_to_binary(port)
    var bin_ip = convert_ip_to_binary(ip_address, address_family)

    var ai = sockaddr_in(address_family, bin_port, bin_ip, StaticTuple[8, c_char]())
    return Pointer[sockaddr_in].address_of(ai).bitcast[sockaddr]()


@value
struct Socket:
    var sockfd: Int32
    var address_family: Int
    var socket_type: UInt8
    var protocol: UInt8
    var _closed: Bool
    var _is_connected: Bool

    fn __init__(
        inout self,
        address_family: Int = AF_INET,
        socket_type: UInt8 = SOCK_STREAM,
        protocol: UInt8 = 0,
    ) raises:
        self.address_family = address_family
        self.socket_type = socket_type
        self.protocol = protocol

        var sockfd = socket(address_family, SOCK_STREAM, 0)
        if sockfd == -1:
            raise Error("Socket creation error")
        self.sockfd = sockfd
        self._closed = False
        self._is_connected = False

    fn __init__(
        inout self,
        sockfd: Int32,
        address_family: Int,
        socket_type: UInt8,
        protocol: UInt8,
    ):
        """
        Create a new socket object when you already have a socket file descriptor. Typically through socket.accept().
        """
        self.sockfd = sockfd
        self.address_family = address_family
        self.socket_type = socket_type
        self.protocol = protocol
        self._closed = False
        self._is_connected = True

    fn __enter__(self) -> Self:
        return self

    fn __exit__(inout self) raises:
        if self._is_connected:
            self.shutdown()
        if not self._closed:
            self.close()

    fn __del__(owned self):
        if self._is_connected:
            self.shutdown()
        if not self._closed:
            try:
                self.close()
            except e:
                print("Failed to close socket during deletion: ", e)

    @always_inline
    fn accept(self) raises -> Self:
        """Accept a connection. The socket must be bound to an address and listening for connections.
        The return value is a connection where conn is a new socket object usable to send and receive data on the connection,
        and address is the address bound to the socket on the other end of the connection.
        """
        var their_addr_ptr = Pointer[sockaddr].alloc(1)
        var sin_size = socklen_t(sizeof[socklen_t]())
        var new_sockfd = accept(
            self.sockfd, their_addr_ptr, Pointer[socklen_t].address_of(sin_size)
        )
        if new_sockfd == -1:
            raise Error("Failed to accept connection")

        return Self(new_sockfd, self.address_family, self.socket_type, self.protocol)

    fn listen(self, backlog: Int = 0) raises:
        """Enable a server to accept connections.

        Args:
            backlog: The maximum number of queued connections. Should be at least 0, and the maximum is system-dependent (usually 5).
        """
        var queued = backlog
        if backlog < 0:
            queued = 0
        if listen(self.sockfd, queued) == -1:
            raise Error("Failed to listen for connections")

    @always_inline
    fn bind(self, address: String, port: Int) raises:
        """Bind the socket to address. The socket must not already be bound. (The format of address depends on the address family).

        Args:
            address: String - The IP address to bind the socket to.
            port: The port number to bind the socket to.
        """
        var sockaddr_pointer = build_sockaddr_pointer(
            address, port, self.address_family
        )

        if bind(self.sockfd, sockaddr_pointer, sizeof[sockaddr_in]()) == -1:
            _ = shutdown(self.sockfd, SHUT_RDWR)
            raise Error("Binding socket failed. Wait a few seconds and try again?")

    @always_inline
    fn file_no(self) -> Int32:
        """Return the file descriptor of the socket."""
        return self.sockfd

    @always_inline
    fn get_sock_name(self) raises -> String:
        """Return the address of the socket."""
        if self._closed:
            raise Error("Socket is closed")

        # TODO: Add check to see if the socket is bound and error if not.

        var socket_address_pointer = Pointer[sockaddr].alloc(1)
        var sin_size = socklen_t(sizeof[socklen_t]())
        var status = getsockname(
            self.sockfd, socket_address_pointer, Pointer[socklen_t].address_of(sin_size)
        )
        if status == -1:
            raise Error("Failed to get socket name")
        var addr_in = socket_address_pointer.bitcast[sockaddr_in]().load()

        return convert_binary_ip_to_string(addr_in.sin_addr.s_addr, AF_INET, 16)

    fn get_peer_name(self) raises -> String:
        """Return the address of the peer connected to the socket."""
        if self._closed:
            raise Error("Socket is closed.")

        # TODO: Add check to see if the socket is bound and error if not.

        var socket_address_pointer = Pointer[sockaddr].alloc(1)
        var sin_size = socklen_t(sizeof[socklen_t]())
        var status = getpeername(
            self.sockfd, socket_address_pointer, Pointer[socklen_t].address_of(sin_size)
        )
        if status == -1:
            raise Error(
                "Failed to get the address of the peer connected to the socket."
            )
        var addr_in = socket_address_pointer.bitcast[sockaddr_in]().load()

        return convert_binary_ip_to_string(addr_in.sin_addr.s_addr, AF_INET, 16)

    fn get_sock_opt(self, option_name: Int) raises -> Int:
        """Return the value of the given socket option.

        Args:
            option_name: The socket option to get.
        """
        var option_value_pointer = Pointer[c_void].alloc(1)
        var option_len = socklen_t(sizeof[socklen_t]())
        var option_len_pointer = Pointer.address_of(option_len)
        var status = getsockopt(
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
        """Return the value of the given socket option.

        Args:
            option_name: The socket option to set.
            option_value: UInt8 - The value to set the socket option to.
        """
        var option_value_pointer = Pointer[UInt8].address_of(option_value)
        var status = setsockopt(
            self.sockfd, SOL_SOCKET, option_name, option_value_pointer, sizeof[c_int]()
        )
        if status == -1:
            raise Error("setsockopt failed.")

    fn connect(self, address: String, port: Int):
        """Connect to a remote socket at address.

        Args:
            address: String - The IP address to connect to.
            port: The port number to connect to.
        """
        var sockaddr_pointer = build_sockaddr_pointer(
            address, port, self.address_family
        )

        if connect(self.sockfd, sockaddr_pointer, sizeof[sockaddr_in]()) == -1:
            print("failed to connect")
            self.shutdown()
            return  # Ensure exit if connection fails

    fn send(self, data: Bytes) raises -> Int:
        """Send data to the socket. The socket must be connected to a remote socket.
        
        Args:
            data: The data to send.
        """
        var header_pointer = Pointer[Int8](data._vector.data.value).bitcast[UInt8]()

        var bytes_sent = send(self.sockfd, header_pointer, strlen(header_pointer), 0)
        if bytes_sent == -1:
            raise Error("Failed to send message")

        return bytes_sent

    fn send_all(self, data: Bytes, max_attempts: Int = 3) raises:
        """Send data to the socket. The socket must be connected to a remote socket.
        
        Args:
            data: The data to send.
            max_attempts: The maximum number of attempts to send the data.
        """
        var header_pointer = Pointer[Int8](data._vector.data.value).bitcast[UInt8]()
        var total_bytes_sent = 0
        var attempts = 0

        # Try to send all the data in the buffer. If it did not send all the data, keep trying but start from the offset of the last successful send.
        while total_bytes_sent < len(data):
            if attempts > max_attempts:
                raise Error(
                    "Failed to send message after "
                    + String(max_attempts)
                    + " attempts."
                )

            var bytes_sent = send(
                self.sockfd,
                header_pointer.offset(total_bytes_sent),
                strlen(header_pointer.offset(total_bytes_sent)),
                0,
            )
            if bytes_sent == -1:
                raise Error(
                    "Failed to send message, wrote"
                    + String(total_bytes_sent)
                    + "bytes before failing."
                )
            total_bytes_sent += bytes_sent
            attempts += 1

    fn send_to(self, data: Bytes, address: String, port: Int) raises -> Int:
        """Send data to the a remote address by connecting to the remote socket before sending.
        The socket must be not already be connected to a remote socket.

        Args:
            data: The data to send.
            address: The IP address to connect to.
            port: The port number to connect to.
        """
        var header_pointer = Pointer[Int8](data._vector.data.value).bitcast[UInt8]()
        self.connect(address, port)
        return self.send(data)

    fn receive(self, bytes_to_receive: Int = 4096) raises -> Bytes:
        """Receive data from the socket."""
        # Not ideal since we can't use the pointer from the Bytes struct directly. So we use a temporary pointer to receive the data.
        # Then we copy all the data over.
        var buf = Bytes(bytes_to_receive)
        var ptr = Pointer[UInt8]().alloc(bytes_to_receive)
        var bytes_recieved = recv(self.sockfd, ptr, bytes_to_receive, 0)
        if bytes_recieved == -1:
            raise Error("Failed to receive message from socket.")

        var int8_ptr = ptr.bitcast[Int8]()
        for i in range(bytes_recieved):
            buf.append(int8_ptr[i])

        return buf

    fn receive_into(self, inout buf: Bytes, bytes_to_receive: Int = 4096) raises -> Int:
        """Receive data from the socket and write it to the buffer provided."""
        var ptr = Pointer[UInt8]().alloc(bytes_to_receive)
        var bytes_recieved = recv(self.sockfd, ptr, bytes_to_receive, 0)
        if bytes_recieved == -1:
            raise Error("Failed to receive message from socket.")

        var int8_ptr = ptr.bitcast[Int8]()
        for i in range(bytes_recieved):
            buf.append(int8_ptr[i])

        return bytes_recieved

    fn shutdown(self):
        _ = shutdown(self.sockfd, SHUT_RDWR)

    fn close(inout self) raises:
        """Mark the socket closed.
        Once that happens, all future operations on the socket object will fail. The remote end will receive no more data (after queued data is flushed).
        """
        self.shutdown()
        var close_status = close(self.sockfd)
        if close_status == -1:
            raise Error("Failed to close socket")

        self._closed = True

    fn get_timeout(self) raises -> Seconds:
        """Return the timeout value for the socket."""
        return self.get_sock_opt(SO_RCVTIMEO)

    fn set_timeout(self, duration: Seconds) raises:
        """Set the timeout value for the socket.

        Args:
            duration: Seconds - The timeout duration in seconds.
        """
        self.set_sock_opt(SO_RCVTIMEO, duration)

    fn send_file(self, file: FileHandle, offset: Int = 0) raises:
        var data = file.read_bytes()
        var bytes = Bytes(4096)
        var count = 0

        for i in range(data.bytecount()):
            bytes[i + 0] = data[i]
            count += 1

        self.send_all(bytes)


fn contains(vector: DynamicVector[String], value: String) -> Bool:
    for i in range(vector.size):
        if vector[i] == value:
            return True
    return False


struct SocketIO(io.Reader, io.Writer, io.Closer):
    var socket: Socket
    var _mode: String
    var _reading: Bool
    var _writing: Bool
    var _timeout_occurred: Bool

    fn __init__(inout self, socket: Socket, mode: String) raises:
        var modes = DynamicVector[String]()
        modes.append("r")
        modes.append("w")
        if not contains(modes, mode):
            raise Error("Invalid mode. Must be 'r', 'w', or 'rw'.")

        self.socket = socket
        self._mode = mode
        self._writing = "w" in mode
        self._reading = "r" in mode
        self._timeout_occurred = False

    fn __moveinit__(inout self, owned existing: Self):
        self.socket = existing.socket ^
        self._mode = existing._mode ^
        self._writing = existing._writing
        self._reading = existing._reading
        self._timeout_occurred = existing._timeout_occurred

    fn is_readable(self) -> Bool:
        return self._reading

    fn is_writable(self) -> Bool:
        return self._writing

    fn read(inout self, inout dest: Bytes) -> Result[Int]:
        var bytes_received: Int
        try:
            bytes_received = self.socket.receive_into(dest)
        except e:
            return Result(0, WrappedError(e))

        return Result(bytes_received, None)

    fn write(inout self, src: Bytes) -> Result[Int]:
        var bytes_written: Int
        try:
            bytes_written = self.socket.send(src)
        except e:
            return Result(0, WrappedError(e))

        return Result(bytes_written, None)

    fn seek(self, offset: Int, whence: Int) -> Int:
        return 0

    fn close(inout self) raises:
        self.socket.close()


# TODO: Should return socket object
fn create_connection(address: String, port: Int, *, timeout: Int = 3600):
    """Connect to a remote socket at address.

    Args:
        address: The IP address to connect to.
        port: The port number to connect to.
        timeout: The timeout duration in seconds.
    """
    ...


## TODO: Implement
fn create_server(
    address: String,
    port: Int,
    *,
    family: Int = AF_INET,
    backlog: Int = 0,
    reuse_port: Bool = False,
):
    """Create a new server socket and bind it to the address and port.

    Args:
        address: The IP address to bind the server to.
        port: The port number to bind the server to.
        family: The address family of the server socket.
        backlog: The maximum number of queued connections.
        reuse_port: Whether to allow the socket to be bound to an address that is already in use.
    """
    ...


# TODO: Implement
fn has_dualstack_ipv6_support() -> Bool:
    """Return True if the system supports creating a socket that can accept both IPv4 and IPv6 connections.
    """
    return False


# TODO: Implement
fn get_fully_qualified_domain_name(name: String = "") -> String:
    """Return the fully qualified domain name for the current host."""
    return ""
