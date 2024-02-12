from http_client.client import HTTPClient, Headers
from http_client.socket import Socket
from http_client.uri import QueryParams, URI
from http_client.stdlib_extensions.builtins import dict, HashableStr, bytes


fn main() raises:
    var client = HTTPClient("www.httpbin.org", "54.224.28.82", 80)
    var headers = Headers()
    headers["Connection"] = "close"
    # headers["Content-Length"] = len(uri._query_string)
    headers["Content-Type"] = "application/json"
    var response = client.post("/post", headers)
    print(response)

    # # Simple GET request
    # var client = HTTPClient("www.example.com", "93.184.216.34", 80)
    # var response = client.get("/")
    # print(response)

    # # GET request with headers and query params (should return 400)
    # var query_params = QueryParams()
    # query_params["world"] = "hello"
    # query_params["foo"] = "bar"

    # var uri = URI("http", "www.google.com", "")
    # _ = uri.set_query_string(query_params)

    # client = HTTPClient(uri.get_full_uri(), "142.251.116.106", 80)
    # var headers = Headers()
    # headers["Connection"] = "close"
    # headers["Content-Length"] = len(uri._query_string)
    # headers["MyHeader"] = "123"
    # response = client.get("/", headers)
    # print(response)

    # # PUT request
    # client = HTTPClient("www.google.com", "142.251.116.106", 80)
    # response = client.put("/")
    # print(response)
