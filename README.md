# mojo-http-client

![Mojo 24.4](https://img.shields.io/badge/Mojo%F0%9F%94%A5-24.4-purple)

A barebones HTTP/1.1 client for Mojo using only Mojo and external C calls.

Thanks to the following for a large chunk of the code for working with sockets via external calls to C!

- https://github.com/saviorand/lightbug_http/tree/main
- https://github.com/gabrieldemarmiesse/mojo-stdlib-extensions/tree/master

## Usage

Currently, it's a simple client. It's able to send requests and parse response strings into a Response struct, and pass some data along.


```mojo
from http_client.client import HTTPClient, Headers


fn test_post() raises:
    var test = MojoTest("Testing client.post")

    # Add headers
    var headers = Headers()
    headers["Connection"] = "close"

    # Add data
    var data = Dict[String, String]()
    data["hello"] = "world"

    var response = HTTPClient().post("www.httpbin.org", "/post", headers=headers, data=data)
    test.assert_equal(response.status_code, 200)
    test.assert_equal(response.status_message, "OK")
    test.assert_equal(response.headers["Content-Type"], "application/json")
    test.assert_equal(response.scheme, "http")


# Simple GET request
fn test_get() raises:
    var test = MojoTest("Testing client.get")
    var response = HTTPClient().get("www.example.com", "/", 80)
    print(response)
    test.assert_equal(response.status_code, 200)
    test.assert_equal(response.status_message, "OK")
    test.assert_equal(response.scheme, "http")
```

## TODO

- Add SSL support
- Add HTTP/2 support
- Add tests
- Fix URI query params logic. String termination messes up the host name.
