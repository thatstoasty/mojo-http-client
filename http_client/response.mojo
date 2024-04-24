from .client import Headers


fn split(input_string: String, sep: String = " ", owned maxsplit: Int = -1) -> List[String]:
    """The separator can be multiple characters long."""
    var result = List[String]()
    if maxsplit == 0:
        result.append(input_string)
        return result
    if maxsplit < 0:
        maxsplit = len(input_string)

    if not sep:
        for i in range(len(input_string)):
            result.append(input_string[i])

        return result

    var output = List[String]()
    var start = 0
    var split_count = 0

    for end in range(len(input_string) - len(sep) + 1):
        if input_string[end : end + len(sep)] == sep:
            output.append(input_string[start:end])
            start = end + len(sep)
            split_count += 1

            if maxsplit > 0 and split_count >= maxsplit:
                break

    output.append(input_string[start:])
    return output


@value
struct Response(Stringable):
    var original_message: String
    var scheme: String
    var protocol: String
    var status_code: Int
    var status_message: String
    var headers: Headers
    var body: String

    fn __init__(inout self):
        self.scheme = ""
        self.protocol = ""
        self.status_code = 0
        self.status_message = ""
        self.original_message = ""
        self.headers = Headers()
        self.body = ""

    fn __init__(inout self, response: String) raises:
        self.original_message = response

        # Split into status + headers and body. TODO: Only supports HTTP/1.1 Format for now
        var chunks = split(response, "\r\n\r\n", 1)
        var lines = chunks[0].split("\n")
        var status_line = lines[0].split(" ")

        var scheme_and_proto = status_line[0].split("/")
        self.scheme = scheme_and_proto[0].lower()
        self.protocol = status_line[0]
        self.status_code = atol(status_line[1])
        self.status_message = status_line[2]

        self.headers = Headers()
        for i in range(1, len(lines), 1):
            var line = lines[i]
            var parts = line.split(": ")
            if len(parts) == 2:
                self.headers[parts[0]] = parts[1]

        self.body = ""
        if len(chunks) > 1:
            self.body = chunks[1]

    fn __str__(self) -> String:
        return self.original_message

    fn __repr__(self) -> String:
        return self.original_message
