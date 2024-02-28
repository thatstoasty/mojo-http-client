from testing import testing
from http_client.uri import QueryParams, URI


fn test_uri() raises:
    var uri = URI("http", "www.example.com", "/")
    var query_params = QueryParams()
    query_params["test"] = "param"
    query_params["test2"] = "param2"
    _ = uri.set_query_string(query_params)

    testing.assert_equal(uri.scheme, "http")
    testing.assert_equal(uri.host, "www.example.com")
    testing.assert_equal(uri.path, "/")
    testing.assert_equal(uri.get_full_uri(), "http://www.example.com/?test=param&test2=param2")
    testing.assert_equal(uri._query_string, "test=param&test2=param2")

    # Should also work by passing in the full path
    var uri2 = URI("http://www.example.com/")
    _ = uri2.set_query_string(query_params)
    testing.assert_equal(uri2.scheme, "http")
    testing.assert_equal(uri2.host, "www.example.com")
    testing.assert_equal(uri2.path, "/")
    testing.assert_equal(uri2.get_full_uri(), "http://www.example.com/?test=param&test2=param2")
    testing.assert_equal(uri2._query_string, "test=param&test2=param2")


fn run_tests() raises:
    print("\n\x1B[38;2;249;38;114mRunning uri.mojo tests\x1B[0m")
    test_uri()