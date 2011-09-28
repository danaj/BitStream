package Data::BitStream::Code::Golomb;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::Golomb::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Golomb::VERSION = '0.02';
}

use Mouse::Role;
requires qw(read write put_unary get_unary);

# Usage:
#
#   $stream->put_golomb( $m, $value );
#
# encode $value using Golomb coding.  The quotient of $value / $m is encoded
# with Unary, and the remainder is written in truncated binary form.
#
# Note that Rice(k) = Golomb(2^k).  Hence if $m is a power of 2, then this
# will be equal to the Rice code of log2(m).
#
#   $stream->put_golomb( sub { my $self=shift; $self->put_gamma(@_); }, $m, $value );
#
# This form allows Golomb coding with any integer coding method replacing
# Unary coding.  The most common use of this is Gamma encoding, but interesting
# results can be obtained with Delta and Fibonacci codes as well.

sub put_golomb {
  my $self = shift;
  my $sub;
  my $m = shift;
  # Check if the first argument is actually a sub to use
  if (ref $m eq 'CODE') {
    $sub = $m;
    $m = shift;
  }
  die "m must be >= 1" unless $m >= 1;

  return( (defined $sub) ? $sub->($self, @_) : $self->put_unary(@_) ) if $m==1;
  my $b = 1;
  { my $v = $m-1;  $b++ while ($v >>= 1); }  # $b is ceil(log2($m))
  my $threshold = (1 << $b) - $m;            # will be 0 if m is a power of 2

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;

    # Obvious but incorrect for large values (you'll get negative r values).
    #    my $q = int($val / $m);
    #    my $r = $val - $q * $m;
    # Correct way:
    my $r = $val % $m;
    my $q = ($val - $r) / $m;
    die unless ($r >= 0) && ($r < $m) && ($q==int($q)) && (($q*$m+$r) == $val);

    (defined $sub)  ?  $sub->($self, $q)  :  $self->put_unary($q);

    if ($r < $threshold) {
      $self->write($b-1, $r);
    } else {
      $self->write($b, $r + $threshold);
    }
  }
  1;
}
sub get_golomb {
  my $self = shift;
  my $sub;
  my $m = shift;
  # Check if the first argument is actually a sub to use
  if (ref $m eq 'CODE') {
    $sub = $m;
    $m = shift;
  }
  die "m must be >= 1" unless $m >= 1;

  return( (defined $sub) ? $sub->($self, @_) : $self->get_unary(@_) ) if $m==1;
  my $b = 1;
  { my $v = $m-1;  $b++ while ($v >>= 1); }   # $b is ceil(log2($m))
  my $threshold = (1 << $b) - $m;             # will be 0 if m is a power of 2

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $q = (defined $sub)  ?  $sub->($self)  :  $self->get_unary();
    last unless defined $q;
    my $val = $q * $m;
    if ($threshold == 0) {
      $val += $self->read($b);
    } else {
      my $first = $self->read($b-1);
      if ($first >= $threshold) {
        $first = ($first << 1) + $self->read(1) - $threshold;
      }
      $val += $first;
    }
    push @vals, $val;
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;

# ABSTRACT: A Role implementing Golomb codes

=pod

=head1 NAME

Data::BitStream::Code::Golomb - A Role implementing Golomb codes

=head1 VERSION

version 0.02

=head1 DESCRIPTION

A role written for L<Data::BitStream> that provides get and set methods for
Golomb codes.  The role applies to a stream object.

Beware that with the default unary coding for the quotient, these codes can
become extraordinarily long for values much larger than C<m>.

=head1 METHODS

=head2 Provided Object Methods

=over 4

=item B< put_golomb($m, $value) >

=item B< put_golomb($m, @values) >

Insert one or more values as Golomb codes with parameter m.  Returns 1.

=item B< put_golomb(sub { ... }, $m, @values) >

Insert one or more values as Golomb codes using the user provided subroutine
instead of the traditional Unary code for the base.  For example, the common
Gamma-Golomb encoding can be performed using the sub:

  sub { shift->put_gamma(@_); }

=item B< get_golomb($m) >

=item B< get_golomb($m, $count) >

Decode one or more Golomb codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=item B< get_golomb(sub { ... }, $m) >

Similar to the regular get method except using the user provided subroutine
instead of unary encoding the base.  For example:

  sub { shift->get_gamma(@_); }

=back

=head2 Parameters

The parameter C<m> must be an integer greater than or equal to 1.

The quotient of C<value / m> is encoded using unary (or via the user
supplied subroutine), followed by the remainder in truncated binary form.

Note: if C<m == 1> then the result will be coded purely using unary (or the
supplied sub) coding.

Note: if C<m> is a power of 2 (C<m = 2^k> for some non-negative integer
C<k>), then the result is equal to the simpler C<Rice(k)> code, where the
operations devolve into a shift and mask.

For a general array of integers, the value of C<m> leading to the smallest sum
of codes is approximately 0.69 * the average of the values. (citation needed)

Golomb coding is often preceeded by a step that adapts the parameter to the
data seen so far.

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

=item B< get_unary >

=item B< put_unary >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item L<Data::BitStream::Code::Rice>

=item L<Data::BitStream::Code::GammaGolomb>

=item L<Data::BitStream::Code::ExponentialGolomb>

=item L<http://en.wikipedia.org/wiki/Golomb_coding>

=item S.W. Golomb, "Run-length encodings", IEEE Transactions on Information Theory, vol 12, no 3, pp 399-401, 1966.

=item R.F. Rice and R. Plaunt, "Adaptive Variable-Length Coding for Efficient Compression of Spacecraft Television Data", IEEE Transactions on Communications, vol 16, no 9, pp 889-897, Dec. 1971.

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2011 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
