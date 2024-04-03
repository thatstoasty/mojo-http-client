from collections.optional import Optional
from collections.dict import Dict, KeyElement
from external.gojo.builtins import Bytes
from external.gojo.strings import StringBuilder
from .socket import Socket, get_ip_address
from .response import Response


@value
struct StringKey(KeyElement):
    var s: String

    fn __init__(inout self, owned s: String):
        self.s = s ^

    fn __init__(inout self, s: StringLiteral):
        self.s = String(s)

    fn __hash__(self) -> Int:
        return hash(self.s)

    fn __eq__(self, other: Self) -> Bool:
        return self.s == other.s

    fn __ne__(self, other: Self) -> Bool:
        return self.s != other.s

    fn __str__(self) -> String:
        return self.s


alias Headers = Dict[StringKey, String]


fn build_request_message(
    host: String,
    path: String,
    method: String,
    headers: Optional[Headers],
    data: Optional[Dict[StringKey, String]] = None,
) -> String:
    var header = method.upper() + " " + path + " HTTP/1.1\r\n"
    header += "Host: " + host + "\r\n"

    if headers:
        var headers_mapping = headers.value()

        for pair in headers_mapping.items():
            if pair[].key == "Connection":
                header += "Connection: " + pair[].value + "\r\n"
            elif pair[].key == "Content-Type":
                header += "Content-Type: " + pair[].value + "\r\n"
            elif pair[].key == "Content-Length":
                header += "Content-Length: " + pair[].value + "\r\n"
            else:
                header += String(pair[].key.s) + ": " + pair[].value + "\r\n"
    else:
        # default to closing the connection so socket.receive() does not hang
        header += "Connection: close\r\n"

    # TODO: Only support dictionaries with string data for now
    if data:
        var data_string = stringify_data(data.value())
        header += "Content-Length: " + String(len((data_string))) + "\r\n"
        header += "Content-Type: application/json\r\n"
        header += "\r\n" + data_string + "\r\n"

    header += "\r\n"
    return header


fn stringify_data(data: Dict[StringKey, String]) -> String:
    var key_count = data.size
    var builder = StringBuilder()
    _ = builder.write_string("{")

    var key_index = 0
    for pair in data.items():
        _ = builder.write_string('"')
        _ = builder.write_string(pair[].key.s)
        _ = builder.write_string('"')
        _ = builder.write_string(':"')
        _ = builder.write_string(pair[].value)
        _ = builder.write_string('"')

        # Add comma for all elements except last
        if key_index != key_count - 1:
            _ = builder.write_string(",")
            key_index += 1

    _ = builder.write_string("}")
    return str(builder)


@value
struct HTTPClient:
    var host: String
    var port: Int

    fn send_request(
        self,
        method: String,
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[Dict[StringKey, String]] = None,
    ) raises -> Response:
        var message = build_request_message(self.host, path, method, headers, data)
        var socket = Socket()

        # TODO: The message_len will break with unicode characters as they vary from 1-4 bytes.
        var message_len = len(message)
        var bytes_to_send = Bytes(message)
        var bytes_sent = socket.send_to(
            bytes_to_send, get_ip_address(self.host), self.port
        )
        if bytes_sent != message_len:
            raise Error(
                "Failed to send the entire message. Bytes sent:"
                + String(bytes_sent)
                + " Message length:"
                + String(message_len)
            )

        # Response buffer to store all the data from the socket. TODO: Might need more than 4096 bytes, but how do I make the size dynamic?
        var response_buffer = Bytes(4096)

        # Copy repsonse data from the socket into the response buffer until the socket is closed or no more data is available.
        var bytes_read = 0
        while True:
            var byte_stream = socket.receive()
            if len(byte_stream) == 0:
                break

            response_buffer += byte_stream
            bytes_read += len(byte_stream)

        # Using a StringRef to avoid pointer double free shenanigans.
        var response = Response(response_buffer)
        socket.shutdown()
        socket.close()
        return response

    fn get(
        self,
        path: String,
        headers: Optional[Headers] = None,
    ) raises -> Response:
        return self.send_request("GET", path, headers=headers)

    fn post(
        self,
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[Dict[StringKey, String]] = None,
    ) raises -> Response:
        return self.send_request("POST", path, headers=headers, data=data)

    fn put(
        self,
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[Dict[StringKey, String]] = None,
    ) raises -> Response:
        return self.send_request("PUT", path, headers=headers, data=data)

    fn delete(
        self,
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[Dict[StringKey, String]] = None,
    ) raises -> Response:
        return self.send_request("DELETE", path, headers=headers)

    fn patch(
        self,
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[Dict[StringKey, String]] = None,
    ) raises -> Response:
        return self.send_request("PATCH", path, headers=headers, data=data)

    fn head(
        self,
        path: String,
        headers: Optional[Headers] = None,
    ) raises -> Response:
        return self.send_request("HEAD", path, headers=headers)

    fn options(
        self,
        path: String,
        headers: Optional[Headers] = None,
    ) raises -> Response:
        return self.send_request("DELETE", path, headers=headers)
