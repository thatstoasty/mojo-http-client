from testing import testing
from http_client.socket import get_ip_address, Socket
from http_client.c.net import SO_REUSEADDR, PF_UNIX


# TODO: There's some additional garbage added to the end of the ip address result. Taking a substring of [:-1] does NOT work while [:9] does
# fn test_get_ip_address() raises:
#     print("Testing get_ip_address")
#     var ip = get_ip_address("localhost")
#     testing.assert_equal(ip, "127.0.0.1")


fn run_tests() raises:
    print("\n\x1B[38;2;249;38;114mRunning socket.mojo tests\x1B[0m")
    # test_get_ip_address()