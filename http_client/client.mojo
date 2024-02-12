from external.libc import (
    socket,
    AF_INET,
    SOCK_STREAM,
    SOL_SOCKET,
    SO_REUSEADDR,
    bind,
    listen,
    accept,
    close,
    recv,
    send,
    setsockopt,
    connect,
    sockaddr,
    socklen_t,
    c_void,
    inet_pton,
    c_uint,
    to_char_ptr,
    htons,
    sockaddr_in,
    c_char,
    shutdown,
    strlen,
    SHUT_RDWR,
    Str
)
from memory import memset, memcpy


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

fn test_client():
    # let ip_addr = "127.0.0.1"  # The server's hostname or IP address
    let ip_addr = "93.184.216.34"
    # let port = 8080  # The port used by the server
    let port = 80
    let address_family = AF_INET

    let ip_buf = Pointer[c_void].alloc(4)
    let conv_status = inet_pton(address_family, to_char_ptr(ip_addr), ip_buf)
    let raw_ip = ip_buf.bitcast[c_uint]().load()

    print("inet_pton: " + raw_ip.__str__() + " :: status: " + conv_status.__str__())

    let bin_port = htons(UInt16(port))
    print("htons: " + "\n" + bin_port.__str__())

    var ai = sockaddr_in(address_family, bin_port, raw_ip, StaticTuple[8, c_char]())
    let ai_ptr = Pointer[sockaddr_in].address_of(ai).bitcast[sockaddr]()

    let sockfd = socket(address_family, SOCK_STREAM, 0)
    if sockfd == -1:
        print("Socket creation error")
    print("sockfd: " + "\n" + sockfd.__str__())

    if connect(sockfd, ai_ptr, sizeof[sockaddr_in]()) == -1:
        _ = shutdown(sockfd, SHUT_RDWR)
        print("Connection error")
        return  # Ensure to exit if connection fails

    # let msg = to_char_ptr("Hello, world Server")
    let msg = to_char_ptr("GET /index.html HTTP/1.1\r\nHost: www.example.com\r\n\r\n")
    
    let bytes_sent = send(sockfd, msg, strlen(msg), 0)
    if bytes_sent == -1:
        print("Failed to send message")
    else:
        print("Message sent")

    let buf_size = 1024
    let buf = Pointer[UInt8]().alloc(buf_size)
    let bytes_recv = recv(sockfd, buf, buf_size, 0)
    if bytes_recv == -1:
        print("Failed to receive message")
    else:
        print("Received Message: ")
        print(String(buf.bitcast[Int8](), bytes_recv))

    _ = shutdown(sockfd, SHUT_RDWR)
    print("Closing connection")
    let close_status = close(sockfd)
    if close_status == -1:
        print("Failed to close socket")


# fn curl(input: String) -> UInt8:
#     return external_call["curl", Str, Str](input)


fn main():
    test_socket()
    # let socket = socket(AF_INET, SOCK_STREAM, 0)
    # print(socket)

    # let server = "142.250.113.102"

    # # /* fill in the structure */
    # memset[sockaddr](server.as_pointer(), 0, sizeof[sockaddr]())
    # # memset(&serv_addr, 0, sizeof(serv_addr))
    # # serv_addr.sin_family = AF_INET;
    # # serv_addr.sin_port = htons(portno);
    # # memcpy(&serv_addr.sin_addr.s_addr,server->h_addr,server->h_length);

    # # # /* connect the socket */
    # # if (connect(socket, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
    # #     error("ERROR connecting");

    # let server_address_ptr = Pointer[sockaddr].alloc(1)
    # var sin_size = socklen_t(sizeof[socklen_t]())
    # var connection = connect(socket, server_address_ptr, sizeof[socklen_t]())
    # print(connection)