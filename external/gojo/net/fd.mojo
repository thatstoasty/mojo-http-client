import ..io
from ..builtins import Byte
from ..syscall import (
    recv,
    send,
    close,
    strlen,
    FileDescriptorBase,
)

alias O_RDWR = 0o2


struct FileDescriptor(FileDescriptorBase):
    var fd: Int
    var is_closed: Bool

    # This takes ownership of a POSIX file descriptor.
    fn __moveinit__(inout self, owned existing: Self):
        self.fd = existing.fd
        self.is_closed = existing.is_closed

    fn __init__(inout self, fd: Int):
        self.fd = fd
        self.is_closed = False

    fn __del__(owned self):
        if not self.is_closed:
            var err = self.close()
            if err:
                print(str(err))

    fn close(inout self) -> Error:
        """Mark the file descriptor as closed."""
        var close_status = close(self.fd)
        if close_status == -1:
            return Error("FileDescriptor.close: Failed to close socket")

        self.is_closed = True
        return Error()

    fn dup(self) -> Self:
        """Duplicate the file descriptor."""
        var new_fd = external_call["dup", Int, Int](self.fd)
        return Self(new_fd)

    fn read(inout self, inout dest: List[Byte]) -> (Int, Error):
        """Receive data from the file descriptor and write it to the buffer provided."""
        var bytes_received = recv(
            self.fd,
            DTypePointer[DType.uint8](dest.unsafe_ptr()).offset(dest.size),
            dest.capacity,
            0,
        )
        if bytes_received == -1:
            return 0, Error("Failed to receive message from socket.")
        dest.size += bytes_received

        if bytes_received < dest.capacity:
            return bytes_received, Error(io.EOF)

        return bytes_received, Error()

    fn write(inout self, src: List[Byte]) -> (Int, Error):
        """Write data from the buffer to the file descriptor."""
        var bytes_sent = send(self.fd, src.unsafe_ptr(), strlen(src.unsafe_ptr()), 0)
        if bytes_sent == -1:
            return 0, Error("Failed to send message")

        return bytes_sent, Error()
