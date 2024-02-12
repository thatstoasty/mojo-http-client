from .socket import Socket

fn build_header_string(host: String, path: String, method: String, data: String = "") -> String:
    var header = method.toupper() + " " + path + " HTTP/1.1\r\n"
    header += "Host: " + host + "\r\n"
    # var header += "Content-Length: " + data.len() + "\r\n"
    header += "Connection: close\r\n"
    header += "\r\n"
    return header


@value
struct HTTPClient():
    var host: String
    var port: Int

    fn send_request(self, path: String, method: String, data: String = "") -> String:
        let header_string = build_header_string(self.host, path, method)
        var socket = Socket()
        socket.connect("93.184.216.34", self.port)
        socket.send(header_string)
        let response = socket.receive()
        socket.shutdown()
        socket.close()
        return response

    fn get(self, path: String) -> String:
        return self.send_request(path, "GET")
    
    fn post(self, path: String, data: String) -> String:
        return self.send_request(path, "POST")
    
    fn put(self, path: String, data: String) -> String:
        return self.send_request(path, "PUT")
    
    fn delete(self, path: String) -> String:
        return self.send_request(path, "DELETE")
    
    fn patch(self, path: String, data: String) -> String:
        return self.send_request(path, "PATCH")
    
    fn head(self, path: String) -> String:
        return self.send_request(path, "HEAD")
    
    fn options(self, path: String) -> String:
        return self.send_request(path, "DELETE")
    