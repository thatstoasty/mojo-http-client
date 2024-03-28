from tests.wrapper import MojoTest
from http_client.uri import QueryParams, URI


fn test_uri() raises:
    var test = MojoTest("Testing URI")
    var uri = URI("http", "www.example.com", "/")
    var query_params = QueryParams()
    query_params["test"] = "param"
    query_params["test2"] = "param2"
    _ = uri.set_query_string(query_params)

    test.assert_equal(uri.scheme, "http")
    test.assert_equal(uri.host, "www.example.com")
    test.assert_equal(uri.path, "/")
    test.assert_equal(uri.get_full_uri(), "http://www.example.com/?test=param&test2=param2")
    test.assert_equal(uri._query_string, "test=param&test2=param2")

    # Should also work by passing in the full path
    var uri2 = URI("http://www.example.com/")
    _ = uri2.set_query_string(query_params)
    test.assert_equal(uri2.scheme, "http")
    test.assert_equal(uri2.host, "www.example.com")
    test.assert_equal(uri2.path, "/")
    test.assert_equal(uri2.get_full_uri(), "http://www.example.com/?test=param&test2=param2")
    test.assert_equal(uri2._query_string, "test=param&test2=param2")


fn main() raises:
    test_uri()