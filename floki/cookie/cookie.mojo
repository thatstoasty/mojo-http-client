"""The `Cookie` type representing a single HTTP cookie."""
# from floki.header import HeaderKey, Header
from floki.cookie.duration import Duration
from floki.cookie.expiration import Expiration
from floki.cookie.same_site import SameSite
from mojo_datetime import DateTime


@fieldwise_init
struct Cookie(Copyable, Equatable, Writable):
    """Represents an HTTP cookie with its attributes and provides methods for constructing, manipulating, and serializing cookies.
    """

    comptime EXPIRES = "Expires"
    """The `Expires` attribute of a cookie, indicating the expiration date and time of the cookie.
    """
    comptime MAX_AGE = "Max-Age"
    """The `Max-Age` attribute of a cookie, indicating the maximum age of the cookie in seconds.
    """
    comptime DOMAIN = "Domain"
    """The `Domain` attribute of a cookie, indicating the domain for which the cookie is valid.
    """
    comptime PATH = "Path"
    """The `Path` attribute of a cookie, indicating the URL path for which the cookie is valid.
    """
    comptime SECURE = "Secure"
    """The `Secure` attribute of a cookie, indicating that the cookie should only be sent over HTTPS.
    """
    comptime HTTP_ONLY = "HttpOnly"
    """The `HttpOnly` attribute of a cookie, indicating that the cookie should not be accessible via JavaScript.
    """
    comptime SAME_SITE = "SameSite"
    """The `SameSite` attribute of a cookie, indicating the cross-site request behavior of the cookie.
    """
    comptime PARTITIONED = "Partitioned"
    """The `Partitioned` attribute of a cookie, indicating that the cookie is partitioned.
    """

    comptime SEPERATOR = "; "
    """The separator string used to delimit cookie attributes in the `Set-Cookie` header value.
    """
    comptime EQUAL = "="
    """The equal sign used to separate cookie attribute names and values in the `Set-Cookie` header value.
    """

    var name: String
    """The name of the cookie."""
    var value: String
    """The value of the cookie."""
    var expires: Expiration
    """The expiration setting for the cookie, which can be a specific datetime or session-scoped."""
    var secure: Bool
    """Whether the cookie should only be sent over secure connections (HTTPS)."""
    var partitioned: Bool
    """Whether the cookie is partitioned, meaning it is isolated to a specific top-level site."""
    var domain: Optional[String]
    """The domain for which the cookie is valid. If not specified, defaults to the host of the request URL."""
    var path: Optional[String]
    """The URL path for which the cookie is valid. If not specified, defaults to `/`."""

    def __init__(
        out self,
        var name: String,
        var value: String,
        var expires: Expiration = Expiration(),
        domain: Optional[String] = Optional[String](None),
        path: Optional[String] = Optional[String](None),
        *,
        secure: Bool = False,
        partitioned: Bool = False,
    ):
        """Constructs a Cookie with the given attributes.

        Args:
            name: The name of the cookie.
            value: The value of the cookie.
            expires: The expiration setting for the cookie.
            domain: The domain the cookie is valid for.
            path: The URL path the cookie is valid for.
            secure: Whether the cookie should only be sent over HTTPS.
            partitioned: Whether the cookie is partitioned.
        """
        self.name = name
        self.value = value
        self.expires = expires^
        self.domain = domain
        self.path = path
        self.secure = secure
        self.partitioned = partitioned

    def __init__[origin: Origin, //](out self, header: StringSpan[origin]) raises:
        """Constructs a Cookie by parsing a tab-separated libcurl cookie-list string.

        Parameters:
            origin: The origin of the StringSpan.

        Args:
            header: A tab-separated libcurl cookie-list string containing cookie fields
                    (domain, partitioned, path, secure, expires, name, value).

        Raises:
            Error: If the cookie-list string cannot be parsed.
        """
        var raw_parts = header.split("\t")
        var parts: List[StringSpan[origin].Immutable] = [part for part in raw_parts]
        self.domain = String(parts[0])
        self.partitioned = parts[1] == "TRUE"
        self.path = String(parts[2])
        self.secure = parts[3] == "TRUE"
        # libcurl cookie-list expiration is a Unix timestamp in seconds, or 0 for session cookies.
        self.expires = Expiration.from_libcurl_expires(parts[4])
        self.name = String(parts[5])
        self.value = String(parts[6])

    def write_to(self, mut writer: Some[Writer]):
        """Writes a debug representation of the cookie to a writer.

        Args:
            writer: The writer to which the cookie will be written.
        """
        writer.write("Cookie(", "name=", self.name, ", value=", self.value, ")")

    def clear_cookie(mut self):
        """Invalidates the cookie by clearing its expiration."""
        # self.max_age = None
        self.expires = Expiration.invalidate()

    # def to_header(self) raises -> Header:
    #     return Header(HeaderKey.SET_COOKIE, self.build_header_value())

    def build_header_value(self) -> String:
        """Builds the `Set-Cookie` header value string for this cookie.

        Returns:
            The complete header value string including all cookie attributes.
        """
        var header_value = String(self.name, Self.EQUAL, self.value)
        if self.expires.is_datetime():
            try:
                var v = self.expires.http_date_timestamp()
                if v:
                    header_value.write(Self.SEPERATOR, Self.EXPIRES, Self.EQUAL, v.value())
            except:
                # TODO: This should be a hardfail however Writeable trait write_to method does not raise
                # the call flow needs to be refactored
                pass

        # if self.max_age:
        #     header_value.write(
        #         Self.SEPERATOR, Self.MAX_AGE, Self.EQUAL, String(self.max_age.value().total_seconds)
        #     )
        if self.domain:
            header_value.write(Self.SEPERATOR, Self.DOMAIN, Self.EQUAL, self.domain.value())
        if self.path:
            header_value.write(Self.SEPERATOR, Self.PATH, Self.EQUAL, self.path.value())
        if self.secure:
            header_value.write(Self.SEPERATOR, Self.SECURE)
        # if self.http_only:
        #     header_value.write(Self.SEPERATOR, Self.HTTP_ONLY)
        # if self.same_site:
        #     header_value.write(Self.SEPERATOR, Self.SAME_SITE, Self.EQUAL, String(self.same_site.value()))
        if self.partitioned:
            header_value.write(Self.SEPERATOR, Self.PARTITIONED)
        return header_value^

    def is_expired(self, now: DateTime) -> Bool:
        """Checks whether the cookie has expired relative to the given time.

        Session-scoped cookies (those without a specific expiration datetime)
        are never considered expired by this check.

        Args:
            now: The point in time to compare the cookie's expiration against.

        Returns:
            True if the cookie has a datetime expiration that is at or before `now`, False otherwise.
        """
        if self.expires.is_datetime():
            return self.expires.datetime.value() <= now
        return False
