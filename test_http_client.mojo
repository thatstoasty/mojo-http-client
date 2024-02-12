from http_client import HttpClient, Headers


alias CONTENT_TYPE = "Content-Type"
alias APPLICATION_JSON = "application/json"


fn main() raises:
    let client = HttpClient("www.google.com")
    var headers = Headers()
    headers[CONTENT_TYPE] = APPLICATION_JSON
    let response = client.get("/", Headers())