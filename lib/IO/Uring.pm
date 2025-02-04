package IO::Uring;

use strict;
use warnings;

use XSLoader;

XSLoader::load(__PACKAGE__, __PACKAGE__->VERSION);

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

B<Note>: this is an early release and this module should still be regarded experimental. Backwards compatibility is not yet guaranteed.

=method new($queue_size)

This creates a new uring object, with the given submission queue size.

=method run_once($min_events = 1)

This will submit all pending requests, and process at least C<$min_events> completed (but up to C<$queue_size>) events.

=method accept($sock, $flags, $s_flags, $callback)

Equivalent to C<accept4($fh, $flags)>.

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

This waits for another process. C<$id_type> specifies the type of ID used and must be one of C<P_PID> (C<$id> is a PID), C<P_PGID> (C<$id> is a process group), C<P_PIDFD> (C<$id> is a PID fd) or C<P_ALL> (C<$id> is ignored, wait for any child). C<$info> must be a L<Signal::Info|Signal::Info> object that must be kept alive through the callback, it will contain the result of the event. C<$options> is a bitset of C<WEXITED>, C<WSTOPPED> C<WCONTINUED>, C<WNOWAIT>; typically it would be C<WEXITED>. C<$flags> is currently unused and must be C<0>.

=method write($fh, $buffer, $offset, $s_flags, $callback)

Equivalent to C<send($fh, $buffer, $flags)>. The buffer must be kept alive, typically by enclosing over it in the callback.
