from http_client.client import HTTPClient, Headers
from http_client.socket import Socket
from http_client.uri import QueryParams, URI
from http_client.stdlib_extensions.builtins import dict, HashableStr, bytes


fn main() raises:
    var query_params = QueryParams()
    query_params["world"] = "hello"
    query_params["foo"] = "bar"

    var uri = URI("http", "www.google.com", "")
    _ = uri.set_query_string(query_params)

    var client = HTTPClient(uri.get_full_uri(), "142.251.116.106", 80)
    var headers = Headers()
    headers["Connection"] = "close"
    headers["MyHeader"] = "123"
    let response = client.get("/", headers)
    print(response)
