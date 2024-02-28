from collections.optional import Optional
from .socket import Socket, get_ip_address
from .stdlib_extensions.builtins import dict, HashableStr, bytes

alias Headers = dict[HashableStr, String]

fn build_request_message(
    host: String, 
    path: String, 
    method: String, 
    headers: Optional[Headers], 
    data: Optional[dict[HashableStr, String]] = None
) -> String:
    var header = method.toupper() + " " + path + " HTTP/1.1\r\n"
    header += "Host: " + host + "\r\n"

    if headers:
        let headers_mapping = headers.value()

        for pair in headers_mapping.items():
            if pair.key == "Connection":
                header += "Connection: " + pair.value + "\r\n"
            elif pair.key == "Content-Type":
                header += "Content-Type: " + pair.value + "\r\n"
            elif pair.key == "Content-Length":
                header += "Content-Length: " + pair.value + "\r\n"
            else:
                header += String(pair.key) + ": " + pair.value + "\r\n"

    # TODO: Only support dictionaries with string data for now
    if data:
        let data_string = stringify_data(data.value())
        header += "Content-Length: " + String(len((data_string))) + "\r\n"
        header += "Content-Type: application/json\r\n"
        header += "\r\n" + data_string + "\r\n"

    header += "\r\n"
    return header


fn stringify_data(data: dict[HashableStr, String]) -> String:
    var result: String = "{"
    for pair in data.items():
        result += '\"' + String(pair.key) + '\"' + ":" \
        '\"' + pair.value + '\"'
    
    result += "}"
    return result


@value
struct HTTPClient():
    var host: String
    var port: Int

    fn send_request(
        self,
        method: String,
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) raises -> String:
        let message = build_request_message(self.host, path, method, headers, data)
        print(message)
        var socket = Socket()
        socket.connect(get_ip_address(self.host), self.port)
        socket.send(message)
        let response = socket.receive() # TODO: call receive until all data is fetched, receive should also just return bytes
        socket.shutdown()
        socket.close()
        return response

    fn get(
        self, 
        path: String,
        headers: Optional[Headers] = None,
    ) raises -> String:
        return self.send_request("GET", path, headers=headers)
    
    fn post(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) raises -> String:
        return self.send_request("POST", path, headers=headers, data=data)
    
    fn put(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) raises -> String:
        return self.send_request("PUT", path, headers=headers, data=data)
    
    fn delete(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) raises -> String:
        return self.send_request("DELETE", path, headers=headers)
    
    fn patch(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) raises -> String:
        return self.send_request("PATCH", path, headers=headers, data=data)
    
    fn head(
        self, 
        path: String,
        headers: Optional[Headers] = None,
    ) raises -> String:
        return self.send_request("HEAD", path, headers=headers)
    
    fn options(
        self, 
        path: String,
        headers: Optional[Headers] = None,
    ) raises -> String:
        return self.send_request("DELETE", path, headers=headers)
    