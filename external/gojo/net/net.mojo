from collections.optional import Optional
from memory._arc import Arc
import ..io
from ..builtins import Byte, Result, WrappedError
from .socket import Socket
from .address import Addr, TCPAddr


# Time in nanoseconds
alias Duration = Int
alias DEFAULT_BUFFER_SIZE = 4096
alias DEFAULT_TCP_KEEP_ALIVE = Duration(15 * 1000 * 1000 * 1000)  # 15 seconds


trait Listener(Movable):
    fn accept(borrowed self) raises -> Connection:
        ...

    fn close(self) -> Optional[WrappedError]:
        ...

    fn addr(self) -> Addr:
        ...


trait Conn(io.Writer, io.Reader, io.Closer):
    fn local_address(self) -> TCPAddr:
        """Returns the local network address, if known."""
        ...

    fn remote_address(self) -> TCPAddr:
        """Returns the local network address, if known."""
        ...

    # fn set_deadline(self, t: time.Time) -> Error:
    #     """Sets the read and write deadlines associated
    #     with the connection. It is equivalent to calling both
    #     SetReadDeadline and SetWriteDeadline.

    #     A deadline is an absolute time after which I/O operations
    #     fail instead of blocking. The deadline applies to all future
    #     and pending I/O, not just the immediately following call to
    #     read or write. After a deadline has been exceeded, the
    #     connection can be refreshed by setting a deadline in the future.

    #     If the deadline is exceeded a call to read or write or to other
    #     I/O methods will return an error that wraps os.ErrDeadlineExceeded.
    #     This can be tested using errors.Is(err, os.ErrDeadlineExceeded).
    #     The error's Timeout method will return true, but note that there
    #     are other possible errors for which the Timeout method will
    #     return true even if the deadline has not been exceeded.

    #     An idle timeout can be implemented by repeatedly extending
    #     the deadline after successful read or write calls.

    #     A zero value for t means I/O operations will not time out."""
    #     ...

    # fn set_read_deadline(self, t: time.Time) -> Error:
    #     """Sets the deadline for future read calls
    #     and any currently-blocked read call.
    #     A zero value for t means read will not time out."""
    #     ...

    # fn set_write_deadline(self, t: time.Time) -> Error:
    #     """Sets the deadline for future write calls
    #     and any currently-blocked write call.
    #     Even if write times out, it may return n > 0, indicating that
    #     some of the data was successfully written.
    #     A zero value for t means write will not time out."""
    #     ...


@value
struct Connection(Conn):
    var fd: Arc[Socket]

    fn read(inout self, inout dest: List[Byte]) -> Result[Int]:
        var result = self.fd[].read(dest)
        if result.error:
            if str(result.unwrap_error()) != io.EOF:
                return Result[Int](0, result.unwrap_error())

        return result.value

    fn write(inout self, src: List[Byte]) -> Result[Int]:
        var result = self.fd[].write(src)
        if result.error:
            return Result[Int](0, result.unwrap_error())

        return result.value

    fn close(inout self) -> Optional[WrappedError]:
        var err = self.fd[].close()
        if err:
            return err.value()

        return None

    fn local_address(self) -> TCPAddr:
        """Returns the local network address.
        The Addr returned is shared by all invocations of local_address, so do not modify it."""
        return self.fd[].local_address

    fn remote_address(self) -> TCPAddr:
        """Returns the remote network address.
        The Addr returned is shared by all invocations of remote_address, so do not modify it."""
        return self.fd[].remote_address
