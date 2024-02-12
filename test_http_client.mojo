from http_client.client import HTTPClient
from http_client.socket import Socket, get_ip_address

fn main():
    # var client = HTTPClient("www.example.com", "93.184.216.34", 80)
    # let response = client.get("/")
    # print(response)
    # var client = HTTPClient('www.google.com', "142.251.116.106", 80)
    # let response = client.get("/")
    # print(response)
    var client = HTTPClient('http://cat-fact.herokuapp.com', "3.219.96.23", 80)
    let response = client.get("/facts")
    print(response)
    