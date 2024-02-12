from http_client.client import HTTPClient
from http_client.socket import Socket

fn main():
    var client = HTTPClient("www.example.com", 80)
    let response = client.get("/")
    print(response)