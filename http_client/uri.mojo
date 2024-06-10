from collections.dict import Dict
from .client import String


alias QueryParams = Dict[String, String]


fn join(separator: String, iterable: List[String]) -> String:
    var result: String = ""
    for i in range(iterable.__len__()):
        result += iterable[i]
        if i != iterable.__len__() - 1:
            result += separator
    return result


@value
struct URI:
    var raw_host: String
    var host: String
    var scheme: String
    var path: String
    var _query_string: String

    var disable_path_normalization: Bool

    var full_uri: String
    var request_uri: String

    var username: String
    var password: String

    fn __init__(
        inout self,
        full_uri: String,
    ) raises -> None:
        self.raw_host = String()
        self.scheme = String()
        self.path = String()
        self._query_string = String()
        self.host = String()
        self.disable_path_normalization = False
        self.full_uri = full_uri
        self.request_uri = String()
        self.username = String()
        self.password = String()
        self.parse()

    fn __init__(
        inout self,
        scheme: String,
        host: String,
        path: String,
    ) -> None:
        self.raw_host = path
        self.scheme = scheme
        self.path = normalise_path(path, self.raw_host)
        self._query_string = String()
        self.host = host
        self.disable_path_normalization = False
        self.full_uri = String()
        self.request_uri = String()
        self.username = String()
        self.password = String()

    fn __init__(
        inout self,
        path_original: String,
        path: String,
        scheme: String,
        query_string: String,
        host: String,
        disable_path_normalization: Bool,
        full_uri: String,
        request_uri: String,
        username: String,
        password: String,
    ):
        self.raw_host = path_original
        self.scheme = scheme
        self.path = path
        self._query_string = query_string
        self.host = host
        self.disable_path_normalization = disable_path_normalization
        self.full_uri = full_uri
        self.request_uri = request_uri
        self.username = username
        self.password = password

    fn set_path(inout self, path: String) -> Self:
        self.path = normalise_path(path, self.raw_host)
        return self

    fn set_scheme(inout self, scheme: String) -> Self:
        self.scheme = scheme
        return self

    fn set_request_uri(inout self, request_uri: String) -> Self:
        self.request_uri = request_uri
        return self

    fn set_query_string(inout self, query_string: String) -> Self:
        self._query_string = query_string
        return self

    fn set_query_string(inout self, query_params: QueryParams) raises -> Self:
        var params = List[String]()
        for item in query_params.items():
            params.append(item[].key + "=" + item[].value)

        self._query_string = join("&", params)
        return self

    fn set_host(inout self, host: String) -> Self:
        self.host = host
        return self

    fn parse(inout self) raises -> None:
        var raw_uri = String(self.full_uri)

        # Defaults to HTTP/1.1. TODO: Assume http for now, since nothing but http is supported.
        var proto_str: String = "HTTP/1.1"
        _ = self.set_scheme("http")

        # Parse requestURI
        var n = raw_uri.rfind(" ")
        # if n < 0:
        #     n = len(raw_uri)
        #     proto_str = "HTTP/1.0"
        # elif n == 0:
        #     raise Error("Request URI cannot be empty")
        # else:
        #     var proto = raw_uri[n + 1 :]
        #     if proto != "HTTP/1.1":
        #         proto_str = proto

        var request_uri = raw_uri[:n]

        # Parse host from requestURI
        # TODO: String null terminator issues are causing the last character of the host to be cut off.
        n = request_uri.find("://")
        if n >= 0:
            var host_and_port = request_uri[n + 3 :]
            n = host_and_port.find("/")
            if n >= 0:
                self.host = host_and_port[:n]
                request_uri = request_uri[n + 3 :]
            else:
                self.host = host_and_port
                request_uri = "/"
        else:
            n = request_uri.find("/")
            if n >= 0:
                self.host = request_uri[:n]
                request_uri = request_uri[n:]
            else:
                self.host = request_uri
                request_uri = "/"

        # Parse path
        n = request_uri.find("?")
        if n >= 0:
            self.raw_host = request_uri[:n]
            self._query_string = request_uri[n + 1 :]
        else:
            self.raw_host = request_uri
            self._query_string = String()

        self.path = normalise_path(self.raw_host, self.raw_host)

        _ = self.set_request_uri(request_uri)

    fn set_username(inout self, username: String) -> Self:
        self.username = username
        return self

    fn set_password(inout self, password: String) -> Self:
        self.password = password
        return self

    fn get_full_uri(self) -> String:
        var full_uri = self.scheme + "://" + self.host + self.path
        if len(self._query_string) > 0:
            full_uri += "?" + self._query_string
        return full_uri
