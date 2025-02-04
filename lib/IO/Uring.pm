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

=method accept($fh, $flags, $s_flags, $callback)

Equivalent to C<accept4($fh, $flags)>.

=method recv($fh, $buffer, $flags, $s_flags, $callback)

Equivalent to C<recv($fh, $buffer, $flags)>. The buffer must be preallocated to the desired size, the callback received the number of bytes in it that are actually written to. The buffer must be kept alive, typically by enclosing over it in the callback.

=method send($fh, $buffer, $flags, $s_flags, $callback)

Equivalent to C<send($fh, $buffer, $flags)>. The buffer must be kept alive, typically by enclosing over it in the callback.
