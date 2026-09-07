"""HTTP Client."""
import emberjson
from floki.auth import Auth, NoAuth
from floki.body import Body
from floki.callbacks import read_callback, write_callback
from floki.cookie.cookie_jar import CookieJar
from floki.data import RequestData
from floki.errors import RequestError
from floki.forms import FormData
from floki.handlers import _handle_delete, _handle_head, _handle_options, _handle_patch, _handle_post, _handle_put
from floki.headers import Headers
from floki.http import Protocol, RequestMethod, Status
from floki.proxy import Proxy
from floki.response import Response
from floki.retry import Retry
from floki.timeout import Timeout
from floki.tls import TLS
from mojo_curl.easy import Easy, Result
from mojo_curl.list import CurlList
from std.pathlib import Path
from std.time import sleep
from std.utils import Variant


def _build_url_with_query(url: String, query_parameters: Dict[String, String], easy: Easy) raises -> String:
    """Builds a URL with query parameters appended.

    Args:
        url: The base URL to which query parameters will be appended.
        query_parameters: A dictionary of query parameters to append to the URL.
        easy: An instance of `Easy` used for URL encoding.

    Returns:
        The full URL with query parameters appended.

    Raises:
        Error: If there is a failure in URL encoding or setting the URL.
    """
    # Preserve any query string already present on the URL: the first appended
    # parameter needs `&` rather than `?` in that case.
    var separator = "&" if "?" in url else "?"
    var full_url = String(t"{url}{separator}")
    for i, pair in enumerate(query_parameters.items()):
        full_url.write(t"{easy.escape(pair.key)}={easy.escape(pair.value)}")
        if i != len(query_parameters) - 1:
            full_url.write("&")

    return full_url^


struct Session(Movable):
    """A Session object to manage and persist settings across multiple HTTP requests."""

    var easy: Easy
    """Wraps a libcurl easy handle, which is used to configure and perform HTTP requests."""
    var allow_redirects: Bool
    """Indicates whether the session should automatically follow HTTP redirects."""
    var headers: Headers
    """Default headers to include in every request made with this session."""
    var verbose: Bool
    """Indicates whether libcurl's verbose logging mode is enabled for this session."""
    var timeout: Timeout
    """Timeout configuration applied to every request made with this session."""
    var retry: Optional[Retry]
    """Retry policy applied to every request made with this session."""
    var proxy: Optional[Proxy]
    """Proxy configuration applied to every request made with this session."""
    var tls: Optional[TLS]
    """TLS/SSL verification settings applied to every request made with this session."""

    comptime DEFAULT_HEADERS = {
        "User-Agent": "floki/0.4.0",
    }
    """Default headers that are included in every request made with this session, unless overridden by request-specific headers."""

    def __init__(
        out self,
        allow_redirects: Bool = True,
        var headers: Headers = Headers(),
        verbose: Bool = False,
        var timeout: Timeout = Timeout(),
        var retry: Optional[Retry] = None,
        var proxy: Optional[Proxy] = None,
        var tls: Optional[TLS] = None,
    ) raises:
        """Initialize a new Session.

        Args:
            allow_redirects: Whether to follow HTTP redirects automatically.
            headers: Default headers to include in requests.
            verbose: If True, enables libcurl's verbose logging mode for debugging.
            timeout: Timeout configuration applied to every request made with this session.
            retry: Retry policy applied to every request made with this session.
            proxy: Proxy configuration applied to every request made with this session.
            tls: TLS/SSL verification settings applied to every request made with this session.

        Raises:
            Error: If there is a failure in initializing the libcurl easy handle or setting options.
        """
        self.easy = Easy()
        self.allow_redirects = allow_redirects
        self.headers = Headers(materialize[Self.DEFAULT_HEADERS]())
        self.headers.update(headers^)
        self.verbose = verbose
        self.timeout = timeout^
        self.retry = retry^
        self.proxy = proxy^
        self.tls = tls^
        if self.verbose:
            self.raise_if_error(self.easy.verbose(), "Failed to set libcurl verbose mode:")

    def __enter__(var self) -> Self:
        """Context manager entry point.

        Returns the Session by value for use in a `with` statement. The underlying
        libcurl easy handle is released when the Session is destroyed at the end of
        the block; call `close()` to release it sooner.

        Returns:
            The Session instance by value.
        """
        return self^

    def close(deinit self):
        """Cleans up the resources associated with the Session.

        Calling this is optional: the underlying libcurl easy handle is also
        cleaned up when the `Session` is destroyed. Call it to release the
        handle deterministically rather than at end of scope.
        """
        self.easy^.close()

    def raise_if_error(self, code: Result, message: StringSpan) raises Error:
        """Raises an error if the libcurl result code indicates failure.

        Args:
            code: The libcurl result code to check.
            message: The error message prefix to use if the code indicates failure.

        Raises:
            Error: If the code does not indicate success, with a message describing the error.
        """
        if code != Result.OK:
            raise Error(message, " ", self.easy.describe_error(code))

    def send[
        origin: ImmOrigin, //, method: RequestMethod, A: Auth = NoAuth
    ](
        mut self,
        url: String,
        var headers: Headers,
        data: RequestData[origin],
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends an HTTP request and returns the corresponding response.

        The session's `timeout` and `retry` configuration is applied to the request.

        Parameters:
            origin: The origin of the request data.
            method: The HTTP method to use for the request.
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: A dictionary of HTTP headers to include in the request.
            data: An optional `RequestData` variant representing the request body.
            query_parameters: An optional dictionary of query parameters to include in the URL. Appended to the request URL regardless of HTTP method.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.
        """
        try:
            # Set the url
            if query_parameters:
                # Append the query parameters to the URL.
                var full_url = _build_url_with_query(url, query_parameters, self.easy)
                self.raise_if_error(self.easy.url(full_url), "Failed to set URL with query parameters:")
            else:
                self.raise_if_error(self.easy.url(url), "Failed to set URL:")

            # Set the buffer to load the response into
            var response_body = List[Byte](capacity=8192)
            self.raise_if_error(
                self.easy.write_data(Pointer(to=response_body).unsafe_bitcast[NoneType]()),
                "Failed to set write data:",
            )

            # Set the write callback to load the response data into the above buffer.
            self.raise_if_error(self.easy.write_function(write_callback), "Failed to set write function:")

            # Set method specific curl options
            comptime if method == RequestMethod.POST:
                if data.isa[Span[Byte, origin]]():
                    _handle_post(self.easy, data[Span[Byte, origin]])
                else:
                    _handle_post(self.easy, data[Pointer[FileHandle, origin]])
            elif method == RequestMethod.PUT:
                if data.isa[Span[Byte, origin]]():
                    _handle_put(self.easy, data[Span[Byte, origin]])
                else:
                    _handle_put(self.easy, data[Pointer[FileHandle, origin]])
            elif method == RequestMethod.DELETE:
                _handle_delete(self.easy)
            elif method == RequestMethod.PATCH:
                if data.isa[Span[Byte, origin]]():
                    _handle_patch(self.easy, data[Span[Byte, origin]])
                else:
                    _handle_patch(self.easy, data[Pointer[FileHandle, origin]])
            elif method == RequestMethod.HEAD:
                _handle_head(self.easy)
            elif method == RequestMethod.OPTIONS:
                _handle_options(self.easy)

            # Resolve whether to follow redirects: a per-request override takes
            # precedence over the session default.
            var follow_redirects = allow_redirects.value() if allow_redirects else self.allow_redirects
            self.raise_if_error(self.easy.follow_location(enable=follow_redirects), "Failed to set follow location:")

            # Apply the session's timeout configuration. libcurl expects milliseconds.
            if self.timeout.connect:
                self.raise_if_error(
                    self.easy.connect_timeout(Int(self.timeout.connect.value() * 1000)),
                    "Failed to set connect timeout:",
                )
            if self.timeout.total:
                self.raise_if_error(
                    self.easy.timeout(Int(self.timeout.total.value() * 1000)),
                    "Failed to set timeout:",
                )

            # Apply the session's proxy configuration.
            if self.proxy:
                ref proxy = self.proxy.value()
                self.raise_if_error(self.easy.proxy(proxy.url.copy()), "Failed to set proxy:")
                if proxy.username:
                    self.raise_if_error(
                        self.easy.proxy_username(proxy.username.value().copy()),
                        "Failed to set proxy username:",
                    )
                if proxy.password:
                    self.raise_if_error(
                        self.easy.proxy_password(proxy.password.value().copy()),
                        "Failed to set proxy password:",
                    )
                if proxy.no_proxy:
                    self.raise_if_error(
                        self.easy.no_proxy(",".join(proxy.no_proxy)),
                        "Failed to set no_proxy:",
                    )

            # Apply the session's TLS verification settings. Disabling verification
            # is dangerous and should only be used for testing or trusted networks.
            if self.tls:
                ref tls = self.tls.value()
                if not tls.verify:
                    self.raise_if_error(
                        self.easy.ssl_verify_peer(verify=False), "Failed to disable TLS peer verification:"
                    )
                    self.raise_if_error(
                        self.easy.ssl_verify_host(verify=False), "Failed to disable TLS host verification:"
                    )
                if tls.ca_bundle:
                    self.raise_if_error(self.easy.cainfo(tls.ca_bundle.value()), "Failed to set TLS CA bundle:")
                if tls.ca_path:
                    self.raise_if_error(self.easy.capath(tls.ca_path.value()), "Failed to set TLS CA path:")

            # Apply the authentication scheme. A per-request auth takes precedence
            # over the session-level default. Headers already present on the
            # request take precedence over auth-supplied headers.
            if auth:
                auth.value().apply(headers)

            var header_list = CurlList(headers._inner)
            try:
                # If there's any headers set on the session, add them too.
                # but only if they aren't already set in the request-specific headers, since those should take precedence.
                for header in self.headers.items():
                    if header.key not in headers:
                        header_list.append(String(t"{header.key}: {header.value}"))

                # Set headers
                self.raise_if_error(self.easy.http_headers(header_list), "Failed to set HTTP headers:")

                # Enable the cookie engine
                self.raise_if_error(self.easy.cookie_file(), "Failed to enable cookie engine:")

                # Perform the transfer, retrying per the session's retry policy on
                # transfer errors or retryable status codes.
                var attempt = 0
                while True:
                    response_body.clear()  # Discard any partial body from a previous attempt.
                    var perform_result = self.easy.perform()
                    var status_code = Int(self.easy.response_code()) if perform_result == Result.OK else 0

                    if self.retry:
                        ref retry = self.retry.value()
                        var should_retry = perform_result != Result.OK or retry.should_retry(status_code)
                        if should_retry and attempt < retry.max_retries:
                            attempt += 1
                            sleep(retry.backoff_time(attempt))
                            continue

                    # Retries (if any) are exhausted. A failed transfer is surfaced as a
                    # classified `RequestError` so callers can tell a timeout from a
                    # connection failure from a TLS problem.
                    if perform_result != Result.OK:
                        raise RequestError(perform_result)
                    break
            finally:
                header_list^.free()  # Free headers after performing the request.

            return Response(
                body=response_body^,
                headers=self.easy.headers(),
                protocol=Protocol(self.easy.get_scheme()),
                status=Status(Int(self.easy.response_code())),
                cookies=CookieJar(self.easy.cookies()),
                url=self.easy.effective_url(),
            )
        finally:
            self.easy.reset()  # Reset the easy handle to clear any state for the next request.
            if self.verbose:
                _ = self.easy.verbose()

    def get[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a GET request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session
        from floki.auth import BasicAuth

        def main() raises:
            var session = Session()
            var r = session.get("https://httpbin.org/get", auth=BasicAuth("user", "pass"))
        ```
        """
        return self.send[RequestMethod.GET](
            url=url,
            headers=headers^,
            data=RequestData(List[Byte]()),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def post[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        var headers: Headers = Headers(),
        var data: emberjson.Object = {},
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a POST request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: HTTP headers to include in the request.
            data: The data to include in the body of the POST request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.post("https://httpbin.org/post", data={"key": "value"})
        ```
        """
        if "Content-Type" not in headers:
            headers["Content-Type"] = "application/json"
        var json_data: String
        try:
            json_data = emberjson.to_json(data)
        except e:
            raise RequestError(Error(String(e)))
        var json_bytes = json_data.as_bytes()
        return self.send[RequestMethod.POST](
            url=url,
            headers=headers^,
            data=RequestData(json_bytes),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def post[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: FormData,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a POST request with `application/x-www-form-urlencoded` data to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The form fields to include in the body of the POST request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session
        from floki.forms import FormData

        def main() raises:
            var session = Session()
            var r = session.post("https://httpbin.org/post", data=FormData({"key": "value"}))
        ```
        """
        if "Content-Type" not in headers:
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        var encoded = data.encode()
        return self.send[RequestMethod.POST](
            url=url,
            headers=headers^,
            data=RequestData(encoded.as_bytes()),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def post[
        T: Deinitable, A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: T,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a POST request to the specified URL.

        Parameters:
            T: The type of the data to serialize into the request body.
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the POST request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        @fieldwise_init
        struct Point(Deinitable):
            var x: Int
            var y: Int

        def main() raises:
            var session = Session()
            var r = session.post("https://httpbin.org/post", data=Point(0, 1))
        ```
        """
        if "Content-Type" not in headers:
            headers["Content-Type"] = "application/json"
        var json_data: String
        try:
            json_data = emberjson.to_json(data)
        except e:
            raise RequestError(Error(String(e)))
        var json_bytes = json_data.as_bytes()
        return self.send[RequestMethod.POST](
            url=url,
            headers=headers^,
            data=RequestData(json_bytes),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def post[
        origin: ImmOrigin, A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: Span[Byte, origin],
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a POST request to the specified URL.

        Parameters:
            origin: The origin of the data span.
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the POST request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.post("https://httpbin.org/post", data="hello".as_bytes())
        ```
        """
        return self.send[RequestMethod.POST](
            url=url,
            headers=headers^,
            data=RequestData(data),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def post[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: FileHandle,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a POST request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the POST request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            with open("data.json", "r") as file:
                var r = session.post("https://httpbin.org/post", data=file)
        ```
        """
        return self.send[RequestMethod.POST](
            url=url,
            headers=headers^,
            data=RequestData(Pointer(to=data)),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def put[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        var headers: Headers = Headers(),
        var data: emberjson.Object = {},
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PUT request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: HTTP headers to include in the request.
            data: The data to include in the body of the PUT request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.put("https://httpbin.org/put", data={"key": "value"})
        ```
        """
        if "Content-Type" not in headers:
            headers["Content-Type"] = "application/json"
        var json_data: String
        try:
            json_data = emberjson.to_json(data)
        except e:
            raise RequestError(Error(String(e)))
        var json_bytes = json_data.as_bytes()
        return self.send[RequestMethod.PUT](
            url=url,
            headers=headers^,
            data=RequestData(json_bytes),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def put[
        T: Deinitable, A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: T,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PUT request to the specified URL.

        Parameters:
            T: The type of the data to serialize into the request body.
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the PUT request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        @fieldwise_init
        struct Point:
            var x: Int
            var y: Int

        def main() raises:
            var session = Session()
            var r = session.put("https://httpbin.org/put", data=Point(0, 1))
        ```
        """
        if "Content-Type" not in headers:
            headers["Content-Type"] = "application/json"
        var json_data: String
        try:
            json_data = emberjson.to_json(data)
        except e:
            raise RequestError(Error(String(e)))
        var json_bytes = json_data.as_bytes()
        return self.send[RequestMethod.PUT](
            url=url,
            headers=headers^,
            data=RequestData(json_bytes),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def put[
        origin: ImmOrigin, A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: Span[Byte, origin],
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PUT request to the specified URL.

        Parameters:
            origin: The origin of the data span.
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the PUT request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.put("https://httpbin.org/put", data="hello".as_bytes())
        ```
        """
        return self.send[RequestMethod.PUT](
            url=url,
            headers=headers^,
            data=data,
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def put[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: FileHandle,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PUT request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the PUT request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            with open("data.json", "r") as file:
                var r = session.put("https://httpbin.org/put", data=file)
        ```
        """
        return self.send[RequestMethod.PUT](
            url=url,
            headers=headers^,
            data=Pointer(to=data),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def delete[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a DELETE request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.delete("https://httpbin.org/delete")
        ```
        """
        return self.send[RequestMethod.DELETE](
            url=url,
            headers=headers^,
            data=RequestData(List[Byte]()),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def patch[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        var headers: Headers = Headers(),
        var data: emberjson.Object = {},
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PATCH request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: HTTP headers to include in the request.
            data: The data to include in the body of the PATCH request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.patch("https://httpbin.org/patch", data={"key": "value"})
        ```
        """
        if "Content-Type" not in headers:
            headers["Content-Type"] = "application/json"
        var json_data: String
        try:
            json_data = emberjson.to_json(data)
        except e:
            raise RequestError(Error(String(e)))
        var json_bytes = json_data.as_bytes()
        return self.send[RequestMethod.PATCH](
            url=url,
            headers=headers^,
            data=RequestData(json_bytes),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def patch[
        T: Deinitable, A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: T,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PATCH request to the specified URL.

        Parameters:
            T: The type of the data to serialize into the request body.
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the PATCH request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        @fieldwise_init
        struct Point:
            var x: Int
            var y: Int

        def main() raises:
            var session = Session()
            var r = session.patch("https://httpbin.org/patch", data=Point(0, 1))
        ```
        """
        if "Content-Type" not in headers:
            headers["Content-Type"] = "application/json"
        var json_data: String
        try:
            json_data = emberjson.to_json(data)
        except e:
            raise RequestError(Error(String(e)))
        var json_bytes = json_data.as_bytes()
        return self.send[RequestMethod.PATCH](
            url=url,
            headers=headers^,
            data=RequestData(json_bytes),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def patch[
        origin: ImmOrigin, A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: Span[Byte, origin],
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PATCH request to the specified URL.

        Parameters:
            origin: The origin of the data span.
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the PATCH request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.patch("https://httpbin.org/patch", data="hello".as_bytes())
        ```
        """
        return self.send[RequestMethod.PATCH](
            url=url,
            headers=headers^,
            data=data,
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def patch[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        data: FileHandle,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a PATCH request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            data: The data to include in the body of the PATCH request.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            with open("data.json", "r") as file:
                var r = session.patch("https://httpbin.org/patch", data=file)
        ```
        """
        return self.send[RequestMethod.PATCH](
            url=url,
            headers=headers^,
            data=Pointer(to=data),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def head[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends a HEAD request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.head("https://httpbin.org/get")
        ```
        """
        return self.send[RequestMethod.HEAD](
            url=url,
            headers=headers^,
            data=RequestData(List[Byte]()),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )

    def options[
        A: Auth = NoAuth, //
    ](
        mut self,
        var url: String,
        var headers: Headers = Headers(),
        query_parameters: Dict[String, String] = {},
        auth: Optional[A] = None,
        allow_redirects: Optional[Bool] = None,
    ) raises RequestError -> Response:
        """Sends an OPTIONS request to the specified URL.

        Parameters:
            A: The concrete `Auth` scheme type, inferred from `auth`.

        Args:
            url: The URL to which the request is sent.
            headers: HTTP headers to include in the request.
            query_parameters: Query parameters to include in the request URL.
            auth: An optional authentication scheme to apply to the request.
            allow_redirects: Per-request override for following redirects; falls back to the session default when None.

        Returns:
            The received response.

        Raises:
            RequestError: If there is a failure in sending or receiving the message.

        #### Examples:
        ```mojo
        from floki.session import Session

        def main() raises:
            var session = Session()
            var r = session.options("https://httpbin.org/get")
        ```
        """
        return self.send[RequestMethod.OPTIONS](
            url=url,
            headers=headers^,
            data=RequestData(List[Byte]()),
            query_parameters=query_parameters,
            auth=auth,
            allow_redirects=allow_redirects,
        )
