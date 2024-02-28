from http_client.client import HTTPClient, Headers
from http_client.socket import Socket
from http_client.uri import QueryParams, URI
from http_client.stdlib_extensions.builtins import dict, HashableStr, bytes


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
    print(response)


# Simple GET request
fn test_get() raises:
    print("Testing GET")
    let client = HTTPClient("www.example.com", 80)
    let response = client.get("/")
    print(response)


# GET request with headers and query params, returns 400. TODO: Need to fix this, not working atm, returns a 400
fn test_query_params() raises:
    print("Testing query params")
    var query_params = QueryParams()
    query_params["world"] = "hello"
    query_params["foo"] = "bar"

    var uri = URI("http", "www.httpbin.org", "/get")
    _ = uri.set_query_string(query_params)

    # PUT request
    let client = HTTPClient(uri.get_full_uri(), 80)
    let response = client.get("/get")
    print(response)


fn main() raises:
    test_get()
    test_post()
    # test_query_params()