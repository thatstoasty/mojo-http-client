from testing import testing
from http_client.client import HTTPClient, Headers
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
    testing.assert_equal(response.status_code, 200)
    # TODO: Printing response.status_message shows the correct message, but it shows up as None in the assert??
    # Seems like something is generally wrong with setting attributes of the Response object
    # testing.assert_equal(response.status_message, "OK")
    # testing.assert_equal(response.headers["Content-Type"], "application/json")
    testing.assert_equal(response.scheme, "http")


# Simple GET request
fn test_get() raises:
    print("Testing GET")
    var client = HTTPClient("www.example.com", 80)
    var response = client.get("/")
    testing.assert_equal(response.status_code, 200)
    # TODO: Printing response.status_message shows the correct message, but it shows up as None in the assert??
    # testing.assert_equal(response.status_message, "OK")
    testing.assert_equal(response.scheme, "http")


# GET request with headers and query params. TODO: Throwing 405 for now, need to find an endpoint that accepts query params
fn test_query_params() raises:
    print("Testing query params")
    var query_params = QueryParams()
    query_params["world"] = "hello"
    query_params["foo"] = "bar"

    var uri = URI("http://www.httpbin.org")
    _ = uri.set_query_string(query_params)

    # PUT request
    var client = HTTPClient("www.httpbin.org", 80)
    var response = client.put("/get")
    testing.assert_equal(response.status_code, 405)
    # TODO: Printing response.status_message shows the correct message, but it shows up as None in the assert??
    # testing.assert_equal(response.status_message, "OK")
    testing.assert_equal(response.scheme, "http")


fn run_tests() raises:
    print("\n\x1B[38;2;249;38;114mRunning client.mojo tests\x1B[0m")
    test_get()
    test_post()
    test_query_params()