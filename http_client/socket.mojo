from .external.libc import (
    socket,
    connect,
    close,
    recv,
    send,
    shutdown,
    inet_pton,
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
    # SOL_SOCKET,
    # SO_REUSEADDR,
    # bind,
    # listen,
    # accept,
    # setsockopt,
    # socklen_t,
)


@value
struct Socket():
    # var address_family: Int
    # var socket_type: UInt8
    var sockfd: Int32
    var _closed: Bool

    fn __init__(inout self, address_family: Int = AF_INET, socket_type: UInt8 = SOCK_STREAM):
        let sockfd = socket(address_family, SOCK_STREAM, 0)
        if sockfd == -1:
            print("Socket creation error")
        print("sockfd: " + "\n" + sockfd.__str__())
        self.sockfd = sockfd
        self._closed = False
        
    
    fn __enter__(self) -> Self:
        return self
    
    # fn __exit__(inout self):
    #     if not self._closed:
    #         self.close()
                
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
            print("Connection error")
            self.shutdown()
            return  # Ensure to exit if connection fails
    
    fn send(self, header: String):
        let header_ptr = to_char_ptr(header)
    
        let bytes_sent = send(self.sockfd, header_ptr, strlen(header_ptr), 0)
        if bytes_sent == -1:
            print("Failed to send message")
        else:
            print("Message sent")
    
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
        # self.shutdown()
        print("Closing connection")
        let close_status = close(self.sockfd)
        if close_status == -1:
            print("Failed to close socket")
            return

        self._closed = True


fn test_socket():
    # with Socket() as socket:
    #     socket.connect("93.184.216.34", 80)
    #     socket.send("GET /index.html HTTP/1.1\r\nHost: www.example.com\r\nConnection: close\r\n\r\n")
    #     socket.receive()
        # socket.shutdown()
        # socket.close()
    var socket = Socket()
    socket.connect("93.184.216.34", 80)
    socket.send("GET /index.html HTTP/1.1\r\nHost: www.example.com\r\nConnection: close\r\n\r\n")
    let response = socket.receive()
    print(response)
    socket.shutdown()
    socket.close()