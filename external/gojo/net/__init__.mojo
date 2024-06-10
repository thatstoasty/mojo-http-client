"""Adapted from go's net package

A good chunk of the leg work here came from the lightbug_http project! https://github.com/saviorand/lightbug_http/tree/main
"""

from .fd import FileDescriptor
from .socket import Socket
from .tcp import TCPConnection, TCPListener, listen_tcp
from .address import TCPAddr, NetworkType, Addr
from .ip import get_ip_address, get_addr_info
from .dial import dial_tcp, Dialer
from .net import Connection, Conn
