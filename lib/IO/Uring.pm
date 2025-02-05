package IO::Uring;

use strict;
use warnings;

use XSLoader;

XSLoader::load(__PACKAGE__, __PACKAGE__->VERSION);

use Exporter 'import';
# @EXPORT_OK is filled from XS

1;

# ABSTRACT: io_uring for Perl

=head1 SYNOPSIS

 my $ring = IO::Uring->new(32);
 my $buffer = "\0" x 4096;
 $ring->recv($fh, $buffer, MSG_WAITALL, 0, sub($res, $flags) { ... });
 $ring->send($fh, $buffer, 0, 0, sub($res, $flags) { ... });
 $ring->run_once while 1;

=head1 DESCRIPTION

This module is a low-level interface to C<io_uring>, Linux's new asynchronous I/O interface drastically reducing the number of system calls needed to perform I/O. Unlike previous models such as epoll it's based on a proactor model instead of a reactor model, meaning that you schedule asynchronous actions and then get notified by a callback when the action has completed.

Generally speaking, the methods of this class match a system call 1-on-1 (e.g. C<recv>), except that they have two additional argument:

=over 1

=item 1. The submission flags. In particular this allows you to chain actions.

=item 2. A callback. This callback received two integer arguments: a result (on error typically a negative errno value), and the completion flags. This callback will be kept alive by thos module, any other resources that need to be kept alive should be captured by it.

=back

All event methods return an identifier that can be used with C<cancel>.

B<Note>: this is an early release and this module should still be regarded experimental. Backwards compatibility is not yet guaranteed.

=method new($queue_size)

This creates a new uring object, with the given submission queue size.

=method run_once($min_events = 1)

This will submit all pending requests, and process at least C<$min_events> completed (but up to C<$queue_size>) events.

=method accept($sock, $flags, $s_flags, $callback)

Equivalent to C<accept4($fh, $flags)>.

=method cancel($identifier, $flags, $s_flags, $callback = undef)

This cancels a pending request. C<$identifier> should usually be the value return by a previous event method. C<$flags> is usually C<0>, but be C<IORING_ASYNC_CANCEL_ALL>, C<IORING_ASYNC_CANCEL_FD> or C<IORING_ASYNC_CANCEL_ANY>. Note that unlike most event methods the C<$callback> is allowed to be empty.

=method connect($sock, $sockaddr, $s_flags, $callback)

Connect socket C<$sock> to address C<$sockaddr>.

=method read($fh, $buffer, $offset, $s_flags, $callback)

Equivalent to C<pread($fh, $buffer, $offset)>. The buffer must be preallocated to the desired size, the callback received the number of bytes in it that are actually written to. The buffer must be kept alive, typically by enclosing over it in the callback.

=method recv($sock, $buffer, $flags, $s_flags, $callback)

Equivalent to C<recv($fh, $buffer, $flags)>. The buffer must be preallocated to the desired size, the callback received the number of bytes in it that are actually written to. The buffer must be kept alive, typically by enclosing over it in the callback.

=method send($sock, $buffer, $flags, $s_flags, $callback)

Equivalent to C<send($fh, $buffer, $flags)>. The buffer must be kept alive, typically by enclosing over it in the callback.

=method timeout($timespec, $count, $flags, $s_flags, $callback)

This creates a timeout. C<$timespec> must refer to a L<Time::Spec|Time::Spec> object that must be kept alive through the callback. C<$count> is the number of events that should be waited on, typically it would be C<0>. C<$flags> is a bit set that may contain any of the following values: C<IORING_TIMEOUT_ABS>, C<IORING_TIMEOUT_BOOTTIME>, C<IORING_TIMEOUT_REALTIME>, C<IORING_TIMEOUT_ETIME_SUCCESS>, C<IORING_TIMEOUT_MULTISHOT>.

=method waitid($id_type, $id, $info, $options, $flags, $s_flags, $callback)

This waits for another process. C<$id_type> specifies the type of ID used and must be one of C<P_PID> (C<$id> is a PID), C<P_PGID> (C<$id> is a process group), C<P_PIDFD> (C<$id> is a PID fd) or C<P_ALL> (C<$id> is ignored, wait for any child). C<$info> must be a L<Signal::Info|Signal::Info> object that must be kept alive through the callback, it will contain the result of the event. C<$options> is a bitset of C<WEXITED>, C<WSTOPPED> C<WCONTINUED>, C<WNOWAIT>; typically it would be C<WEXITED>. C<$flags> is currently unused and must be C<0>. When the callback is triggered the following entries of C<$info> will be set: C<pid>, C<uid>, C<signo> (will always be C<SIGCHLD>), C<status> and C<code> (C<CLD_EXITED>, C<CLD_KILLED>)

=method write($fh, $buffer, $offset, $s_flags, $callback)

Equivalent to C<send($fh, $buffer, $flags)>. The buffer must be kept alive, typically by enclosing over it in the callback.

=head1 FLAGS

The following flags are all optionally exported:

=head2 Submission flags:

These flags are passed to all event methods, and affect how the submission is processed.

=over 4

=item * C<IOSQE_ASYNC>

Normal operation for io_uring is to try and issue an sqe as
non-blocking first, and if that fails, execute it in an
async manner. To support more efficient overlapped
operation of requests that the application knows/assumes
will always (or most of the time) block, the application
can ask for an sqe to be issued async from the start. Note
that this flag immediately causes the SQE to be offloaded
to an async helper thread with no initial non-blocking
attempt.  This may be less efficient and should not be used
liberally or without understanding the performance and
efficiency tradeoffs.

=item * C<IOSQE_IO_LINK>

When this flag is specified, the SQE forms a link with the
next SQE in the submission ring. That next SQE will not be
started before the previous request completes. This, in
effect, forms a chain of SQEs, which can be arbitrarily
long. The tail of the chain is denoted by the first SQE
that does not have this flag set. Chains are not supported
across submission boundaries. Even if the last SQE in a
submission has this flag set, it will still terminate the
current chain. This flag has no effect on previous SQE
submissions, nor does it impact SQEs that are outside of
the chain tail. This means that multiple chains can be
executing in parallel, or chains and individual SQEs. Only
members inside the chain are serialized. A chain of SQEs
will be broken if any request in that chain ends in error.


=item * C<IOSQE_IO_HARDLINK>

Like IOSQE_IO_LINK , except the links aren't severed if an
error or unexpected result occurs.

=item * C<IOSQE_IO_DRAIN>

When this flag is specified, the SQE will not be started
before previously submitted SQEs have completed, and new
SQEs will not be started before this one completes.

=back

=head2 Completion flags

These are values set in the C<$flags> arguments of the event callbacks. They include:

=over 4

=item * C<IORING_CQE_F_MORE>

If set, the application should expect more completions from
the request. This is used for requests that can generate
multiple completions, such as multi-shot requests, receive,
or accept.

=item * C<IORING_CQE_F_SOCK_NONEMPTY>

If set, upon receiving the data from the socket in the
current request, the socket still had data left on
completion of this request.

=back

=head2 Event specific flags

=head3 cancel

=over 4

=item * C<IORING_ASYNC_CANCEL_ALL>

Cancel all requests that match the given criteria, rather
than just canceling the first one found. Available since
5.19.

=item * C<IORING_ASYNC_CANCEL_FD>

Match based on the file descriptor used in the original
request rather than the user_data. Available since 5.19.

=item * C<IORING_ASYNC_CANCEL_ANY>

Match any request in the ring, regardless of user_data or
file descriptor.  Can be used to cancel any pending request
in the ring. Available since 5.19.

=back

=head3 timeout

=over 4

=item * C<IORING_TIMEOUT_ABS>

The value specified in ts is an absolute value rather than
a relative one.

=item * C<IORING_TIMEOUT_BOOTTIME>

The boottime clock source should be used.

=item * C<IORING_TIMEOUT_REALTIME>

The realtime clock source should be used.

=item * C<IORING_TIMEOUT_ETIME_SUCCESS>

Consider an expired timeout a success in terms of the
posted completion. This means it will not sever dependent
links, as a failed request normally would. The posted CQE
result code will still contain -ETIME in the res value.

=item * C<IORING_TIMEOUT_MULTISHOT>

The request will return multiple timeout completions. The
completion flag IORING_CQE_F_MORE is set if more timeouts
are expected. The value specified in count is the number of
repeats. A value of 0 means the timeout is indefinite and
can only be stopped by a removal request. Available since
the 6.4 kernel.

=back

=head3 waitid

C<waitid> has various constants defined for it. The following values are defined for the C<$idtype>:

=over 4

=item * C<P_PID>

This indicated the identifier is a process identifier.

=item * C<P_PGID>

This indicated the identifier is a process group identifier.

=item * C<P_PIDFD>

This indicated the identifier is a pidfd.

=item * C<P_ALL>

This indicated the identifier will be ignored and any child is waited upon.

=back

The following constants are defined for the C<$options> argument:

=over 4

=item * C<WEXITED>

Wait for children that have terminated.

=item * C<WSTOPPED>

Wait for children that have been stopped by delivery of a signal.

=item * C<WCONTINUED>

Wait for (previously stopped) children that have been
resumed by delivery of SIGCONT.

=item * C<WNOWAIT>

Leave the child in a waitable state; a later wait call can
be used to again retrieve the child status information.

=back
