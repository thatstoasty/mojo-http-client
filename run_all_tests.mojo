import tests.test_client
import tests.test_socket
import tests.test_uri


fn main() raises:
    test_client.run_tests()
    test_socket.run_tests()
    test_uri.run_tests()
    print("All tests passed!")