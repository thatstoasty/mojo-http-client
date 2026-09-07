"""The `CookieJar` type for storing and managing a collection of cookies."""
from mojo_curl.list import CurlList
from mojo_datetime import DateTime
from std.collections.dict import Hasher

from floki.cookie.cookie import Cookie


@fieldwise_init
struct CookieKey(Copyable, KeyElement, Writable):
    """A key for identifying cookies in the CookieJar, based on name, domain, and path."""

    var name: String
    """The cookie name."""
    var domain: String
    """The cookie domain."""
    var path: String
    """The cookie path."""

    @implicit
    def __init__(
        out self,
        name: String,
        domain: Optional[String] = None,
        path: Optional[String] = None,
    ):
        """Constructs a CookieKey from name, domain, and path.

        Args:
            name: The cookie name.
            domain: The cookie domain. Defaults to empty string if None.
            path: The cookie path. Defaults to "/" if None.
        """
        self.name = name
        self.domain = domain.or_else("")
        self.path = path.or_else("/")

    def __hash__[H: Hasher](self, mut hasher: H):
        """Updates hasher with the underlying bytes.

        Parameters:
            H: The hasher type.

        Args:
            hasher: The hasher instance.
        """
        hasher.update(String(self.name, "~", self.domain, "~", self.path).as_bytes())


@fieldwise_init
struct CookieJar(Boolable, Copyable, Defaultable, Sized, Writable):
    """A collection of cookies, indexed by CookieKey (name, domain, path)."""

    var _inner: Dict[CookieKey, Cookie]
    """Internal dictionary storing cookies by their keys."""

    def __init__(out self):
        """Constructs an empty CookieJar."""
        self._inner = Dict[CookieKey, Cookie]()

    def __init__(out self, var *cookies: Cookie) raises:
        """Constructs a CookieJar pre-populated with the given cookies.

        Args:
            cookies: A variable number of Cookie instances to add to the jar.

        Raises:
            Error: If any of the provided cookies are invalid.
        """
        self._inner = Dict[CookieKey, Cookie](capacity=len(cookies))

        def _move_elements(idx: Int, var elt: Cookie) {mut self}:
            self.set_cookie(elt^)

        cookies^.consume_elements(_move_elements)

    def __init__(out self, var raw_cookies: CurlList) raises:
        """Constructs a CookieJar by parsing cookies from a libcurl cookie list.

        Args:
            raw_cookies: A CurlList of raw cookie strings to parse.

        Raises:
            Error: If a cookie string cannot be parsed.
        """
        self._inner = Dict[CookieKey, Cookie]()
        try:
            for cookie in raw_cookies:
                self.set_cookie(Cookie(StringSpan(unsafe_from_utf8=cookie)))
        finally:
            raw_cookies^.free()

    @always_inline
    def __setitem__(mut self, var key: CookieKey, var value: Cookie):
        """Sets a cookie in the jar by key.

        Args:
            key: The CookieKey identifying the cookie.
            value: The Cookie to store.
        """
        self._inner[key^] = value^

    @always_inline
    def __getitem__(
        ref self, ref key: CookieKey
    ) raises -> ref[origin_of(self._inner)._get_owned_interior["value"]] Cookie:
        """Retrieves a cookie from the jar by key.

        Args:
            key: The CookieKey identifying the cookie.

        Returns:
            A reference to the Cookie.

        Raises:
            KeyError: If the key is not found.
        """
        return self._inner[key]

    def get(self, key: CookieKey) -> Optional[Cookie]:
        """Retrieves a cookie from the jar by key, returning None if not found.

        Args:
            key: The CookieKey identifying the cookie.

        Returns:
            The Cookie if found, or None.
        """
        return self._inner.get(key)

    @always_inline
    def __contains__(self, key: CookieKey) -> Bool:
        """Checks if a cookie with the given key exists in the jar.

        Args:
            key: The CookieKey to look up.

        Returns:
            True if the cookie is present.
        """
        return key in self._inner

    @always_inline
    def __contains__(self, key: Cookie) -> Bool:
        """Checks if the given cookie exists in the jar.

        Args:
            key: The Cookie to look up (matched by name, domain, and path).

        Returns:
            True if the cookie is present.
        """
        return CookieKey(key.name, key.domain, key.path) in self

    @always_inline
    def __len__(self) -> Int:
        """Returns the number of cookies in the jar.

        Returns:
            The cookie count.
        """
        return len(self._inner)

    @always_inline
    def __bool__(self) -> Bool:
        """Reports whether the jar contains any cookies.

        Returns:
            True if at least one cookie is present, False otherwise.
        """
        return len(self) > 0

    @always_inline
    def set_cookie(mut self, var cookie: Cookie):
        """Adds or replaces a cookie in the jar.

        Args:
            cookie: The Cookie to store.
        """
        self[CookieKey(cookie.name, cookie.domain, cookie.path)] = cookie^

    def add_headers_to_jar(mut self, headers: List[String]) raises:
        """Parses cookie header strings and adds them to the jar.

        Args:
            headers: A list of raw cookie header strings to parse.

        Raises:
            Error: If a header string cannot be parsed as a cookie.
        """
        for header in headers:
            var cookie: Cookie
            try:
                cookie = Cookie(header)
            except:
                raise Error("Failed to parse cookie header string: ", header)

            self.set_cookie(cookie^)

    def write_to(self, mut writer: Some[Writer]):
        """Writes all cookies as `Set-Cookie` headers to a writer.

        Args:
            writer: The writer to which the cookie headers will be written.
        """
        for cookie in self._inner.values():
            writer.write("set-cookie", ": ", cookie.build_header_value())

    def clear_expired_cookies(mut self) raises:
        """Removes all cookies in the jar that have expired.

        Raises:
            Error: If retrieving the current time fails.
        """
        var now = DateTime.now()
        var keys_to_remove = List[CookieKey]()
        for kv in self._inner.items():
            if kv.value.is_expired(now):
                keys_to_remove.append(kv.key.copy())

        for key in keys_to_remove:
            _ = self._inner.pop(key)
