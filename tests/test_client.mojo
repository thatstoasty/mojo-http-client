from tests.wrapper import MojoTest
from collections.dict import Dict
from http_client.client import HTTPClient, Headers, StringKey
from http_client.uri import QueryParams, URI


fn test_post() raises:
    var test = MojoTest("Testing client.post")
    var client = HTTPClient("www.httpbin.org", 80)

    # Add headers
    var headers = Headers()
    headers["Connection"] = "close"

    # Add data
    var data = Dict[StringKey, String]()
    data["hello"] = "world"

    var response = client.post("/post", headers, data)
    test.assert_equal(response.status_code, 200)
    # TODO: Printing response.status_message shows the correct message, but it shows up as None in the assert??
    # Seems like something is generally wrong with setting attributes of the Response object
    # testing.assert_equal(response.status_message, "OK")
    # testing.assert_equal(response.headers["Content-Type"], "application/json")
    test.assert_equal(response.scheme, "http")


# Simple GET request
fn test_get() raises:
    var test = MojoTest("Testing client.get")
    var client = HTTPClient("www.example.com", 80)
    var response = client.get("/")
    test.assert_equal(response.status_code, 200)
    # TODO: Printing response.status_message shows the correct message, but it shows up as None in the assert??
    # testing.assert_equal(response.status_message, "OK")
    test.assert_equal(response.scheme, "http")


# TODO: Throwing malloc error, fix this test
# GET request with headers and query params. TODO: Throwing 405 for now, need to find an endpoint that accepts query params
fn test_query_params() raises:
    var test = MojoTest("Testing query params")
    var query_params = QueryParams()
    query_params["world"] = "hello"
    query_params["foo"] = "bar"

    var uri = URI("http://www.httpbin.org")
    _ = uri.set_query_string(query_params)

    var client = HTTPClient("www.httpbin.org", 80)
    var response = client.get("/get")
    test.assert_equal(response.status_code, 405)
    # TODO: Printing response.status_message shows the correct message, but it shows up as None in the assert??
    # testing.assert_equal(response.status_message, "OK")
    test.assert_equal(response.scheme, "http")


fn main() raises:
    test_get()
    test_post()
    # test_query_params()