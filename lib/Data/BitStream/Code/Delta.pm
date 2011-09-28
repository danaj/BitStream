package Data::BitStream::Code::Delta;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::Delta::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Delta::VERSION = '0.01';
}

use Mouse::Role;
requires qw(maxbits read write put_gamma get_gamma);

# Elias Delta code.
#
# Store the number of binary bits in Gamma code, then the value in binary
# excepting the top bit which is known from the base.
#
# Large numbers store more efficiently compared to Gamma.  Small numbers take
# more space.

sub put_delta {
  my $self = shift;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    if ($val == ~0) {
      $self->put_gamma($self->maxbits);
    } else {
      my $base = 0;
      { my $v = $val+1; $base++ while ($v >>= 1); }
      $self->put_gamma($base);
      $self->write($base, $val+1)  if $base > 0;
    }
  }
  1;
}

sub get_delta {
  my $self = shift;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $base = $self->get_gamma();
    last unless defined $base;
    if ($base == $self->maxbits) {
      push @vals, ~0;
    } else {
      my $val = 1 << $base;
      $val |= $self->read($base)  if $base > 0;
      push @vals, $val-1;
    }
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;

# ABSTRACT: A Role implementing Elias Delta codes

=pod

=head1 NAME

Data::BitStream::Code::Delta - A Role implementing Elias Delta codes

=head1 VERSION

version 0.01

=head1 DESCRIPTION

A role written for L<Data::BitStream> that provides get and set methods for
the Elias Delta codes.  The role applies to a stream object.

=head1 METHODS

=head2 Provided Object Methods

=over 4

=item B< put_delta($value) >

=item B< put_delta(@values) >

Insert one or more values as Delta codes.  Returns 1.

=item B< get_delta() >

=item B< get_delta($count) >

Decode one or more Delta codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=back

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

=item B< get_gamma >

=item B< put_gamma >

=item B< maxbits >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item Peter Elias, "Universal codeword sets and representations of the integers", IEEE Trans. Information Theory 21(2), pp. 194-203, Mar 1975.

=item Peter Fenwick, "Punctured Elias Codes for variable-length coding of the integers", Technical Report 137, Department of Computer Science, University of Auckland, December 1996

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2011 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
