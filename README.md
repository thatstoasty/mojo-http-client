# mojo-http-client

A barebones HTTP/1.1 client for Mojo using only Mojo and external C calls.

Thanks to the following for a large chunk of the code for working with sockets via external calls to C!

- https://github.com/saviorand/lightbug_http/tree/main
- https://github.com/gabrieldemarmiesse/mojo-stdlib-extensions/tree/master

# Usage
Currently, it's a simple client. It's able to send requests and parse response strings into a Response struct, and pass some data along.


```python
fn test_post() raises:
    print("Testing POST")
    var client = HTTPClient("www.httpbin.org", 80)

    # Add headers
    var headers = Headers()
    headers["Connection"] = "close"

    # Add data
    var data = dict[HashableStr, String]()
    data["hello"] = "world"

    var response = client.post("/post", headers, data)
    print(response.body)


# Simple GET request
fn test_get() raises:
    print("Testing GET")
    var client = HTTPClient("www.example.com", 80)
    var response = client.get("/")
    print(response.body)


# GET request with headers and query params, returns 400. TODO: Need to fix this, not working atm, returns a 400
fn test_query_params() raises:
    print("Testing query params")
    var query_params = QueryParams()
    query_params["world"] = "hello"
    query_params["foo"] = "bar"

    var uri = URI("http", "www.httpbin.org", "/get")
    _ = uri.set_query_string(query_params)

    # PUT request
    var client = HTTPClient(uri.get_full_uri(), 80)
    var response = client.get("/get")
    print(response.body)

fn main() raises:
    test_get()
    test_post()
    # test_query_params()
```

# TODO
- Add SSL support
- Add HTTP/2 support
- Add tests
- Fix URI query params logic. String termination messes up the host name.