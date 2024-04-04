from tests.wrapper import MojoTest
from external.gojo.builtins import Byte
from http_client.socket import get_ip_address, Socket, SocketIO
from http_client.c.net import SO_REUSEADDR, PF_UNIX


fn test_get_ip_address() raises:
    var test = MojoTest("Testing socket.get_ip_address")
    var ip = get_ip_address("localhost")
    test.assert_equal(ip, "127.0.0.1")


fn test_socket_io() raises:
    var test = MojoTest("Testing socket.SocketIO")
    var socket = Socket()
    socket.connect(get_ip_address("www.example.com"), 80)
    var io = SocketIO(socket ^, "w")
    var result = io.write(String("GET / HTTP/1.1\r\n").as_bytes())
    if result.has_error():
        raise result.unwrap_error().error
    test.assert_equal(result.value, 16)
    io.close()


fn main() raises:
    # test_get_ip_address()
    test_socket_io()
