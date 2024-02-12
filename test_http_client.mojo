from http_client.client import HTTPClient, Headers
from http_client.socket import Socket
from http_client.stdlib_extensions.builtins import dict, HashableStr, bytes


fn main():
    # var client = HTTPClient("www.example.com", "93.184.216.34", 80)
    # let response = client.get("/")
    # print(response)
    var headers = Headers()
    headers["Connection"] = "close"
    headers["MyHeader"] = "123"
    var client = HTTPClient('www.google.com', "142.251.116.106", 80)
    let response = client.get("/", headers)
    print(response)
    # var client = HTTPClient('http://cat-fact.herokuapp.com', "3.219.96.23", 80)
    # let response = client.get("/facts")
    # print(response)
    