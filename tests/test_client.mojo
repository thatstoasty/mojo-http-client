from tests.wrapper import MojoTest
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


# # TODO: Throwing malloc error, fix this test
# # GET request with headers and query params. TODO: Throwing 405 for now, need to find an endpoint that accepts query params
# fn test_query_params() raises:
#     var test = MojoTest("Testing query params")
#     var query_params = QueryParams()
#     query_params["world"] = "hello"
#     query_params["foo"] = "bar"

#     var uri = URI("http://www.httpbin.org")
#     _ = uri.set_query_string(query_params)

#     var client = HTTPClient("www.httpbin.org", 80)
#     var response = client.get("/get")
#     test.assert_equal(response.status_code, 405)
#     # TODO: Printing response.status_message shows the correct message, but it shows up as None in the assert??
#     # testing.assert_equal(response.status_message, "OK")
#     test.assert_equal(response.scheme, "http")


fn main() raises:
    test_get()
    test_post()
    # test_query_params()
