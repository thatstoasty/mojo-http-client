from .net import (
    FD,
    SocketType,
    AddressFamily,
    ProtocolFamily,
    SocketOptions,
    AddressInformation,
    send,
    recv,
    open,
    addrinfo,
    addrinfo_unix,
    sockaddr,
    sockaddr_in,
    socklen_t,
    socket,
    connect,
    htons,
    ntohs,
    inet_pton,
    inet_ntop,
    getaddrinfo,
    getaddrinfo_unix,
    gai_strerror,
    to_char_ptr,
    c_charptr_to_string,
    shutdown,
    inet_ntoa,
    bind,
    listen,
    accept,
    setsockopt,
    getsockopt,
    getsockname,
    getpeername,
    SHUT_RDWR,
    SOL_SOCKET,
)
from .file import close, FileDescriptorBase

# Adapted from https://github.com/crisadamo/mojo-Libc . Huge thanks to Cristian!
# C types
alias c_void = UInt8
alias c_char = UInt8
alias c_schar = Int8
alias c_uchar = UInt8
alias c_short = Int16
alias c_ushort = UInt16
alias c_int = Int32
alias c_uint = UInt32
alias c_long = Int64
alias c_ulong = UInt64
alias c_float = Float32
alias c_double = Float64

# `Int` is known to be machine's width
alias c_size_t = Int
alias c_ssize_t = Int

alias ptrdiff_t = Int64
alias intptr_t = Int64
alias uintptr_t = UInt64


fn strlen(s: DTypePointer[DType.uint8]) -> c_size_t:
    """Libc POSIX `strlen` function
    Reference: https://man7.org/linux/man-pages/man3/strlen.3p.html
    Fn signature: size_t strlen(const char *s).

    Args: s: A pointer to a C string.
    Returns: The length of the string.
    """
    return external_call["strlen", c_size_t, DTypePointer[DType.uint8]](s)
