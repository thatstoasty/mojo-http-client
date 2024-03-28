from http_client.socket import get_ip_address, Socket
from http_client.c.net import SO_REUSEADDR, PF_UNIX, SO_RCVTIMEO

# fn main() raises:
#     var ip = get_ip_address("localhost")
#     print(ip)

fn main() raises:
    # TODO: context manager not working yet
    with Socket() as socket:
        socket.bind("0.0.0.0", 8080)

    var socket = Socket(protocol=PF_UNIX)
    socket.bind("0.0.0.0", 8080)
    socket.connect(get_ip_address("www.example.com"), 80)
    print(socket.sockfd)
    print(socket.get_sock_name())
    print(socket.get_peer_name())
    socket.set_socket_option(SO_REUSEADDR, 1)
    print(socket.get_socket_option(SO_REUSEADDR))
    var timeout = 30
    # socket.set_timeout(timeout)
    # print(socket.get_timeout())
    socket.shutdown()
    socket.close()
    # var option_value = socket.get_sock_opt(SO_REUSEADDR)
    # print(option_value)
    # socket.connect(self.ip, self.port)
    # socket.send(message)
    # var response = socket.receive() # TODO: call receive until all data is fetched, receive should also just return bytes
    # socket.shutdown()
    # socket.close()
