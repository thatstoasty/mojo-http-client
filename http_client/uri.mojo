from .stdlib_extensions.builtins import dict, HashableStr
from .stdlib_extensions.builtins.string import join


alias QueryParams = dict[HashableStr, String]


# TODO: convenience type, not currently used properly but will be helpful in the future
@value
struct URI():
    var raw_host: String
    var host: String
    var scheme: String
    var path: String
    var _query_string: String
    # var __hash: String

    var disable_path_normalization: Bool

    var full_uri: String
    var request_uri: String

    var username: String
    var password: String

    fn __init__(
        inout self,
        full_uri: String,
    ) -> None:
        self.raw_host = String()
        self.scheme = String()
        self.path = String()
        self._query_string = String()
        # self.__hash = String()
        self.host = String()
        self.disable_path_normalization = False
        self.full_uri = full_uri
        self.request_uri = String()
        self.username = String()
        self.password = String()

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
        # self.__hash = String()
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
        # hash: String,
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
        # self.__hash = hash
        self.host = host
        self.disable_path_normalization = disable_path_normalization
        self.full_uri = full_uri
        self.request_uri = request_uri
        self.username = username
        self.password = password

    # fn path_original(self) -> String:
    #     return self.raw_host

    fn set_path(inout self, path: String) -> Self:
        self.path = normalise_path(path, self.raw_host)
        return self

    # fn set_path_sString(inout self, path: String) -> Self:
    #     self.path = normalise_path(path, self.raw_host)
    #     return self

    # fn path(self) -> String:
    #     var processed_path = self.path
    #     if len(processed_path) == 0:
    #         processed_path = "/"
    #     return String(processed_path)

    fn set_scheme(inout self, scheme: String) -> Self:
        self.scheme = scheme
        return self

    # fn set_scheme_String(inout self, scheme: String) -> Self:
    #     self.scheme = scheme
    #     return self

    # fn scheme(self) -> String:
    #     var processed_scheme = self.scheme
    #     if len(processed_scheme) == 0:
    #         processed_scheme = "http"
    #     return processed_scheme

    # fn is_https(self) -> Bool:
    #     return String_equal(self.scheme, strHttps)

    # fn is_http(self) -> Bool:
    #     return String_equal(self.scheme, strHttp) or len(self.scheme) == 0

    fn set_request_uri(inout self, request_uri: String) -> Self:
        self.request_uri = request_uri
        return self

    # fn set_request_uri_String(inout self, request_uri: String) -> Self:
    #     self.request_uri = request_uri
    #     return self

    fn set_query_string(inout self, query_string: String) -> Self:
        self._query_string = query_string
        return self
    
    fn set_query_string(inout self, query_params: QueryParams) raises -> Self:
        var params = DynamicVector[String]()
        for item in query_params.items():
            params.append(String(item.key) + "=" + item.value)

        self._query_string = join("&", params)
        return self

    # fn set_query_string_String(inout self, query_string: String) -> Self:
    #     self._query_string = query_string
    #     return self

    # fn set_hash(inout self, hash: String) -> Self:
    #     self.__hash = hash
    #     return self

    # fn set_hash_String(inout self, hash: String) -> Self:
    #     self.__hash = hash
    #     return self

    # fn hash(self) -> String:
    #     return self.__hash

    fn set_host(inout self, host: String) -> Self:
        self.host = host
        return self

    # fn set_host_String(inout self, host: String) -> Self:
    #     self.host = host
    #     return self

    # fn host(self) -> String:
    #     return self.host

    fn parse(inout self) raises -> None:
        let raw_uri = String(self.full_uri)

        # Defaults to HTTP/1.1
        var proto_str: String = "HTTP/1.1"

        # Parse requestURI
        var n = raw_uri.rfind(" ")
        if n < 0:
            n = len(raw_uri)
            proto_str = "HTTP/1.0"
        elif n == 0:
            raise Error("Request URI cannot be empty")
        else:
            let proto = raw_uri[n + 1 :]
            if proto != "HTTP/1.1":
                proto_str = proto

        var request_uri = raw_uri[:n]

        # Parse host from requestURI
        n = request_uri.find("://")
        if n >= 0:
            let host_and_port = request_uri[n + 3 :]
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

        _ = self.set_scheme(proto_str)
        _ = self.set_request_uri(request_uri)

    # fn request_uri(self) -> String:
    #     return self.request_uri

    fn set_username(inout self, username: String) -> Self:
        self.username = username
        return self

    # fn set_username_String(inout self, username: String) -> Self:
    #     self.username = username
    #     return self

    fn set_password(inout self, password: String) -> Self:
        self.password = password
        return self

    # fn set_password_String(inout self, password: String) -> Self:
    #     self.password = password
    #     return self

    fn get_full_uri(self) -> String:
        var full_uri = self.scheme + "://" + self.host + self.path
        if len(self._query_string) > 0:
            full_uri += "?" + self._query_string
        return full_uri


fn normalise_path(path: String, path_original: String) -> String:
    # TODO: implement
    return path