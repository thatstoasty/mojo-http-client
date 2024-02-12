from collections.optional import Optional
from .socket import Socket
from .stdlib_extensions.builtins import dict, HashableStr, bytes

alias Headers = dict[HashableStr, String]

fn build_header_string(
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

    header += "\r\n"
    print(header)
    return header


@value
struct HTTPClient():
    var host: String
    var ip: String # Temporary until getaddrinfo issue is resolved
    var port: Int

    fn send_request(
        self,
        method: String,
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) -> String:
        let header_string = build_header_string(self.host, path, method, headers, data)
        var socket = Socket()
        socket.connect(self.ip, self.port)
        socket.send(header_string)
        let response = socket.receive()
        socket.shutdown()
        socket.close()
        return response

    fn get(
        self, 
        path: String,
        headers: Optional[Headers] = None,
    ) -> String:
        return self.send_request("GET", path, headers=headers)
    
    fn post(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) -> String:
        return self.send_request("POST", path, headers=headers, data=data)
    
    fn put(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) -> String:
        return self.send_request("PUT", path, headers=headers, data=data)
    
    fn delete(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) -> String:
        return self.send_request("DELETE", path, headers=headers)
    
    fn patch(
        self, 
        path: String,
        headers: Optional[Headers] = None,
        data: Optional[dict[HashableStr, String]] = None
    ) -> String:
        return self.send_request("PATCH", path, headers=headers, data=data)
    
    fn head(
        self, 
        path: String,
        headers: Optional[Headers] = None,
    ) -> String:
        return self.send_request("HEAD", path, headers=headers)
    
    fn options(
        self, 
        path: String,
        headers: Optional[Headers] = None,
    ) -> String:
        return self.send_request("DELETE", path, headers=headers)
    