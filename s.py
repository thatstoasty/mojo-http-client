import socket

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
# s.setsockopt(0, 2, 1)
s.getsockopt(0, 2)