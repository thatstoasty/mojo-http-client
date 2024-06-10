import external.gojo.io
from external.gojo.builtins import Byte
from external.gojo.strings import StringBuilder
from external.gojo.net.socket import Socket
from external.gojo.net.ip import get_ip_address
from .response import Response


alias Headers = Dict[String, String]


fn build_request_message(
    host: String,
    path: String,
    method: String,
    headers: Optional[Headers],
    data: Optional[Dict[String, String]] = None,
) -> String:
    var header = method.upper() + " " + path + " HTTP/1.1\r\n"
    header += "Host: " + host + "\r\n"

    if headers:
        var headers_mapping = headers.value()[]

        for pair in headers_mapping.items():
            if pair[].key == "Connection":
                header += "Connection: " + pair[].value + "\r\n"
            elif pair[].key == "Content-Type":
                header += "Content-Type: " + pair[].value + "\r\n"
            elif pair[].key == "Content-Length":
                header += "Content-Length: " + pair[].value + "\r\n"
            else:
                header += pair[].key + ": " + pair[].value + "\r\n"
    else:
        # default to closing the connection so socket.receive() does not hang
        header += "Connection: close\r\n"

    # TODO: Only support dictionaries with string data for now
    if data:
        var data_string = stringify_data(data.value()[])
        header += "Content-Length: " + String(len((data_string))) + "\r\n"
        header += "Content-Type: application/json\r\n"
        header += "\r\n" + data_string + "\r\n"

    header += "\r\n"
    return header


fn stringify_data(data: Dict[String, String]) -> String:
    var key_count = data.size
    var builder = StringBuilder()
    _ = builder.write_string("{")

    var key_index = 0
    for pair in data.items():
        _ = builder.write_string('"')
        _ = builder.write_string(pair[].key)
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
    fn send_request(
        self,
        method: String,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
        data: Optional[Dict[String, String]] = None,
    ) raises -> Response:
        var message = build_request_message(host, path, method, headers, data)
        print(message)
        var socket = Socket()

        # TODO: The message_len will break with unicode characters as they vary from 1-4 bytes.
        var message_len = len(message)
        var bytes_to_send = message.as_bytes()
        var bytes_sent = socket.send_to(bytes_to_send, get_ip_address(host), port)
        if bytes_sent != message_len:
            raise Error(
                "Failed to send the entire message. Bytes sent:"
                + str(bytes_sent)
                + " Message length:"
                + str(message_len)
            )

        var bytes: List[UInt8]
        var err: Error
        bytes, err = io.read_all(socket)
        bytes.append(0)

        var response = Response(String(bytes))
        socket.shutdown()
        err = socket.close()
        if err:
            raise err
        return response

    fn get(
        self,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
    ) raises -> Response:
        return self.send_request("GET", host, path, port, headers=headers)

    fn post(
        self,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
        data: Optional[Dict[String, String]] = None,
    ) raises -> Response:
        return self.send_request("POST", host, path, port, headers=headers, data=data)

    fn put(
        self,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
        data: Optional[Dict[String, String]] = None,
    ) raises -> Response:
        return self.send_request("PUT", host, path, port, headers=headers, data=data)

    fn delete(
        self,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
    ) raises -> Response:
        return self.send_request("DELETE", host, path, port, headers=headers)

    fn patch(
        self,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
        data: Optional[Dict[String, String]] = None,
    ) raises -> Response:
        return self.send_request("PATCH", host, path, port, headers=headers, data=data)

    fn head(
        self,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
    ) raises -> Response:
        return self.send_request("HEAD", host, path, port, headers=headers)

    fn options(
        self,
        host: String,
        path: String,
        port: Int = 80,
        headers: Optional[Headers] = None,
    ) raises -> Response:
        return self.send_request("DELETE", host, path, port, headers=headers)
