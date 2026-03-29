package IO::Uring::BufferGroup;

use strict;
use warnings;

1;

# ABSTRACT: An uring buffer group

=head1 SYNOPSIS

 my $ring = IO::Uring->new($cur, cqe_entries => 2 * $cur);
 my $buffer_group = $ring->add_buffer_group(4096, 8, 0);

 $ring->recv_multishot($fh, 0, 0, $buffer_group->id, 0, sub($res, $flags)) {
     return if $res < 0;
     my $index = $flags >> 16;
     for my $buffer ($buffer_group->get($index, $res)) {
         $ring->send($fh, $buffer, MSG_WAITALL, 0, 0, sub($res, $flags) {
             $buffer_group->release($index);
         });
     }
 });

=head1 DESCRIPTION

Buffer groups are primarily used with multishot receive operations such as
C<recv_multishot> and C<read_multishot>. Instead of supplying a buffer from
user space for each request, the kernel selects a buffer from the group
whenever data arrives.

When a completion occurs, the callback receives the result and completion
flags as usual, and the buffer that was used for the operation can be
retrieved from the buffer group object. After the callback finishes, the
buffer is returned to the group so it can be reused for future operations.

Using provided buffers avoids repeated memory allocation and allows
multishot operations to efficiently deliver multiple completions.

=method consume($index, $size)

This copies the entry C<$index> from the buffer group into a new variable, and releases it.

=method get($index, $size)

Get the read value from the buffer group without copying it.

=method release($index)

This releases the given buffer, you should probably C<get> it first.

=method id()

This returns the id (as passed to C<add_buffer_group>).

# ABSTRACT: a uring buffer group
