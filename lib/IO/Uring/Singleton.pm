package IO::Uring::Singleton;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = 'ring';

use IO::Uring;

our $size = 128;
our %arguments;

my $ring;
sub ring {
    return $ring //= IO::Uring->new($size, %arguments);
}

1;

#ABSTRACT: A shared singleton uring

=head1 SYNOPSIS

 use IO::Uring::Singleton;
 my $ring = IO::Uring::Singleton::ring();

=head2 DESCRIPTION

This module provides a ring singleton to share between different event loop systems.

=func ring

This returns always returns the same ring, that will be created the first time the function is called.
