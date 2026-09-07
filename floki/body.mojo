"""The `Body` type used to represent HTTP request and response payloads."""
import emberjson
from std.collections.string._utf8 import _is_valid_utf8


struct Body(Copyable, Equatable, Sized, Writable):
    """Represents the body of an HTTP request or response.

    At the moment, this only supports JSON serialization and deserialization.
    """

    var body: List[Byte]
    """The raw body content as a list of bytes."""

    def __init__(out self, var body: List[Byte]):
        """Constructs a Body instance from a list of bytes.

        Args:
            body: The body content as a list of bytes.
        """
        self.body = body^

    def __init__[origin: ImmOrigin, //](out self, body: Span[Byte, origin]):
        """Alternate constructor that accepts a Span[Byte] for the body content.

        Parameters:
            origin: The origin of the data span.

        Args:
            body: The body content as a span of bytes.
        """
        self.body = List[Byte](body)

    def __len__(self) -> Int:
        """Returns the length of the body in bytes.

        Returns:
            The number of bytes in the body.
        """
        return len(self.body)

    def as_bytes(self) -> Span[Byte, origin_of(self.body)]:
        """Returns a view of the body content as a span of bytes.

        Returns:
            A `Span[Byte]` referencing the body's underlying data.
        """
        return Span(self.body)

    def as_text(self) raises -> StringSpan[origin_of(self.body)]:
        """Creates and returns a `StringSpan` view of the body content.

        Returns:
            The body content as a string slice.

        Raises:
            Error: If the body content is not valid UTF-8.
        """
        return StringSpan(from_utf8=Span(self.body))

    def as[T: Movable & Deinitable & Defaultable](self, out result: T) raises:
        """Deserializes the body into a value of the given type.

        Use this when you have a struct (or other deserializable type) to parse
        the body into. For ad-hoc, untyped access, use `as_json()` instead.

        Parameters:
            T: The type to deserialize the body into.

        Returns:
            The body content deserialized into a value of type `T`.

        Raises:
            Error: if the body is empty or cannot be parsed as JSON.
        """
        return emberjson.from_json[T](self.as_text())

    def as_json(self) raises -> emberjson.Value:
        """Parses the body as a dynamic JSON document for ad-hoc access.

        Use this to inspect a response without declaring a target type, e.g.
        `body.as_json()["data"]`. To deserialize into a struct, use `as_json[T]()`.

        Returns:
            The body content parsed as an `emberjson.Value`.

        Raises:
            Error: if the body is empty or cannot be parsed as JSON.
        """
        return emberjson.from_json[emberjson.Value](self.as_text())

    def write_to(self, mut writer: Some[Writer]) raises:
        """Writes the body to a writer.

        Args:
            writer: The writer to which the body will be written.

        Raises:
            Error: If the body content is not valid UTF-8.
        """
        writer.write(self.as_text())

    def take_bytes(deinit self) -> List[Byte]:
        """Consumes the body and returns it as List[Byte].

        Returns:
            The body content as a list of bytes.
        """
        return self.body^
