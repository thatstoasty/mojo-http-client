"""HTTP/1.1 200 OK
Age: 450092
Cache-Control: max-age=604800
Content-Type: text/html; charset=UTF-8
Date: Wed, 28 Feb 2024 17:28:07 GMT
Etag: "3147526947+ident"
Expires: Wed, 06 Mar 2024 17:28:07 GMT
Last-Modified: Thu, 17 Oct 2019 07:18:26 GMT
Server: ECS (dab/4B67)
Vary: Accept-Encoding
X-Cache: HIT
Content-Length: 1256
Connection: close

<!doctype html>
<html>
<head>
    <title>Example Domain</title>

    <meta charset="utf-8" />
    <meta http-equiv="Content-type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style type="text/css">
    body {
        background-color: #f0f0f2;
        margin: 0;
        padding: 0;
        font-family: -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", "Open Sans", "Helvetica Neue", Helvetica, Arial, sans-serif;
        
    }
    div {
        width: 600px;
        margin: 5em auto;
        padding: 2em;
        background-color: #fdfdff;
        border-radius: 0.5em;
        box-shadow: 2px 3px 7px 2px rgba(0,0,0,0.02);
    }
    a:link, a:visited {
        color: #38488f;
        text-decoration: none;
    }
    @media (max-width: 700px) {
        div {
            margin: 0 auto;
            width: auto;
        }
    }
    </style>    
</head>

<body>
<div>
    <h1>Example Domain</h1>
    <p>This domain is for use in illustrative examples in documents. You may use this
    domain in literature without prior coordination or asking for permission.</p>
    <p><a href="https://www.iana.org/domains/example">More information...</a></p>
</div>
</body>
</html>"""

from .stdlib_extensions.builtins import dict, HashableStr
from .stdlib_extensions.builtins.string import split


@value
struct Response(Stringable):
    var original_message: String
    var scheme: String
    var protocol: String
    var status_code: Int
    var status_message: String
    var headers: dict[HashableStr, String]
    var body: String

    fn __init__(inout self):
        self.scheme = ""
        self.protocol = ""
        self.status_code = 0
        self.status_message = ""
        self.original_message = ""
        self.headers = dict[HashableStr, String]()
        self.body = ""

    fn __init__(inout self, response: String) raises:
        self.original_message = response

        # Split into status + headers and body. TODO: Only supports HTTP/1.1 Format for now
        let chunks = split(response, "\r\n\r\n", 1)
        let lines = chunks[0].split("\n")
        let status_line = lines[0].split(" ")
        
        var scheme_and_proto = status_line[0].split("/")
        self.scheme = scheme_and_proto[0]
        self.protocol = scheme_and_proto[1]
        self.status_code = atol(status_line[1])
        self.status_message = status_line[2]

        self.headers = dict[HashableStr, String]()
        for i in range(1, len(lines), 1):
            let line = lines[i]
            let parts = line.split(": ")
            if len(parts) == 2:
                self.headers[HashableStr(parts[0])] = parts[1]

        self.body = ""
        if len(chunks) > 1:
            self.body = chunks[1]

    fn __str__(self) -> String:
        return self.original_message

    fn __repr__(self) -> String:
        return self.original_message
