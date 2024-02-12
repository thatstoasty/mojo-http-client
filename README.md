# mojo-http-client

A barebones HTTP/1.1 client for Mojo using only Mojo and external C calls.

Thanks to the following for a large chunk of the code for working with sockets via external calls to C!

- https://github.com/saviorand/lightbug_http/tree/main
- https://github.com/gabrieldemarmiesse/mojo-stdlib-extensions/tree/master

# Usage
Currently, it's a simple client. It's able to send a request and receive a response String, and pass some data along.


```python
from http_client.client import HTTPClient, Headers
from http_client.socket import Socket
from http_client.uri import QueryParams, URI
from http_client.stdlib_extensions.builtins import dict, HashableStr, bytes


fn main() raises:
    # Simple GET request
    var client = HTTPClient("www.example.com", "93.184.216.34", 80)
    var response = client.get("/")
    print(response)

    # GET request with some basic header and query params support (should return 400 in this example)
    var query_params = QueryParams()
    query_params["world"] = "hello"
    query_params["foo"] = "bar"

    var uri = URI("http", "www.google.com", "")
    _ = uri.set_query_string(query_params)
    client = HTTPClient(uri.get_full_uri(), "142.251.116.106", 80)
    var headers = Headers()
    headers["Connection"] = "close"
    headers["Content-Length"] = len(uri._query_string)
    headers["MyHeader"] = "123"
    response = client.get("/", headers)
    print(response)
```

# TODO
- Return a response object instead of a string. 
- Domain to IP address translation via getaddrinfo (`ai_next` points to null pointer, so I'm unable to get the actual result)
- Add SSL support
- Add HTTP/2 support