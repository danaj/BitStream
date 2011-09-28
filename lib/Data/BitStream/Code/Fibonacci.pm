package Data::BitStream::Code::Fibonacci;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::Fibonacci::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Fibonacci::VERSION = '0.02';
}

use Mouse::Role;
requires qw(write put_string get_unary read);

# Fraenkel and Klein, 1996, C1 code.
#
# The C2 code is also supported, though not efficiently.  C3 is not supported.
#
# While most codes we use are 'instantaneous' codes (also variously called
# prefix codes or prefix-free codes), the C2 code is not.  It has to look at
# the first bit of the next code to determine when it has ended.  This has the
# distinct disadvantage that is does not play well with other codes in the
# same stream.  For example, if a C2 code is followed by a zero-based unary
# code then incorrect parsing will ensue.
#
# Note that these are Fib_2 codes.  The concept can be generalized to Fib_m
# where m >= 2.  In particular the m=3 and m=4 codes have proven useful in some
# applications (see papers by Klein et al.).

# Calculate Fibonacci numbers F[2]+ using simple forward calculation.
# Generate enough so we can encode any integer from 0 - ~0.
my @fibs;
{
  my ($v2, $v1) = (0,1);
  while ($v1 <= ~0) {
    ($v2, $v1) = ($v1, $v2+$v1);
    push(@fibs, $v1);
  }
  # @fibs is now (1, 2, 3, 5, 8, 13, ...)
}
die unless defined $fibs[41];  # we use this below

# Since calculating the Fibonacci codes are relatively expensive, cache the
# size and code for small values.
my $fib_code_cache_size = 128;
my @fib_code_cache;

sub put_fib {
  my $self = shift;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;

    if ( ($val < $fib_code_cache_size) && (defined $fib_code_cache[$val]) ) {
      $self->write( @{$fib_code_cache[$val]} );
      next;
    }

    my $d = $val+1;
    my $s =  ($d < $fibs[20])  ?  0  :  ($d < $fibs[40])  ?  21  :  41;
    $s++ while ($d >= $fibs[$s]);

    # Generate 32-bit word directly if possible
    if ($s <= 31) {
      my $word = 1;
      foreach my $f (reverse 0 .. $s) {
        if ($d >= $fibs[$f]) {
          $d -= $fibs[$f];
          $word |= 1 << ($s-$f);
        }
      }
      if ($val < $fib_code_cache_size) {
        $fib_code_cache[$val] = [ $s+1, $word ];
      }
      $self->write($s+1, $word);
      next;
    }

    # Generate the string code.
    my $r = '11';
    $d = $val - $fibs[--$s] + 1;     # (this makes $val = ~0 encode correctly)
    while ($s-- > 0) {
      if ($d >= $fibs[$s]) {
        $d -= $fibs[$s];
        $r .= '1';
      } else {
        $r .= '0';
      }
    }
    $self->put_string(scalar reverse $r);
  }
  1;
}

# We can implement get_fib a lot of different ways.
#
# Simple:
#
#   my $last = 0;
#   while (1) {
#     my $code = $self->read(1);
#     die "Read off end of fib" unless defined $code;
#     last if $code && $last;
#     $val += $fibs[$b] if $code;
#     $b++;
#     $last = $code;
#   }
#
# Exploit knowledge that we have lots of zeros and get_unary is fast.  This
# is 2-10 times faster than reading single bits.
#
#   while (1) {
#     my $code = $self->get_unary();
#     die "Read off end of fib" unless defined $code;
#     last if ($code == 0) && ($b > 0);
#     $b += $code;
#     $val += $fibs[$b];
#     $b++;
#   }
#
# Use readahead(8) and look up the result in a precreated array of all the
# first 8 bit values mapped to the associated prefix code.  While this is
# a neat idea, in practice it is slow in this framework.
#
# Use readahead to read 32-bit chunks at a time and parse them here.

sub get_fib {
  my $self = shift;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $code = $self->get_unary;
    last unless defined $code;
    my $val = 0;
    my $b = -1;
    do {
      die "Read off end of stream" unless defined $code;
      $b += $code+1;
      $val += $fibs[$b];
    } while ($code = $self->get_unary);
    push @vals, $val-1;
  }
  wantarray ? @vals : $vals[-1];
}

# String functions

sub _encode_fib_c1 {
  my $d = shift;
  die "Value must be between 1 and ~0" unless $d >= 1 and $d <= ~0;
  my $s =  ($d < $fibs[20])  ?  0  :  ($d < $fibs[40])  ?  21  :  41;
  $s++ while ($d >= $fibs[$s]);
  my $r = '1';
  while ($s-- > 0) {
    if ($d >= $fibs[$s]) {
      $d -= $fibs[$s];
      $r .= "1";
    } else {
      $r .= "0";
    }
  }
  scalar reverse $r;
}

sub _decode_fib_c1 {
  my $str = shift;
  die "Invalid Fibonacci C1 code" unless $str =~ /^[01]*11$/;
  my $val = 0;
  foreach my $b (0 .. length($str)-2) {
    $val += $fibs[$b]  if substr($str, $b, 1) eq '1';
  }
  $val;
}

sub _encode_fib_c2 {
  my $d = shift;
  die "Value must be between 1 and ~0" unless $d >= 1 and $d <= ~0;
  return '1' if $d == 1;
  my $str = _encode_fib_c1($d-1);
  substr($str, -1, 1) = '';
  substr($str, 0, 0) = '10';
  $str;
}

sub _decode_fib_c2 {
  my $str = shift;
  return 1 if $str eq '1';
  die "Invalid Fibonacci C2 code" unless $str =~ /^10[01]*1$/;
  $str =~ s/^10//;
  my $val = _decode_fib_c1($str . '1') + 1;
  $val;
}

sub put_fib_c2 {
  my $self = shift;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    $self->put_string(_encode_fib_c2($val+1));
  }
  1;
}
sub get_fib_c2 {
  my $self = shift;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $str = '';
    if (0) {
      my $look = $self->read(8, 'readahead');
      last unless defined $look;
      if (($look & 0xC0) == 0xC0) { $self->skip(1); return 0; }
      if (($look & 0xF0) == 0xB0) { $self->skip(3); return 1; }
      if (($look & 0xF8) == 0x98) { $self->skip(4); return 2; }
      if (($look & 0xFC) == 0x8C) { $self->skip(5); return 3; }
      if (($look & 0xFC) == 0xAC) { $self->skip(5); return 4; }
      if (($look & 0xFE) == 0x86) { $self->skip(6); return 5; }
      if (($look & 0xFE) == 0xA6) { $self->skip(6); return 6; }
      if (($look & 0xFE) == 0x96) { $self->skip(6); return 7; }
    }
    my $b = $self->read(1);
    last unless defined $b;
    $str .= $b;
    my $b2 = $self->read(1, 'readahead');
    while ( (defined $b2) && ($b2 != 1) ) {
      my $skip = $self->get_unary;
      $str .= '0' x $skip . '1';
      $b2 = $self->read(1, 'readahead');
    }
    push @vals, _decode_fib_c2($str)-1;
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;

# ABSTRACT: A Role implementing Fibonacci codes

=pod

=head1 NAME

Data::BitStream::Code::Fibonacci - A Role implementing Fibonacci codes

=head1 VERSION

version 0.02

=head1 DESCRIPTION

A role written for L<Data::BitStream> that provides get and set methods for
the Fibonacci codes.  The role applies to a stream object.

=head1 METHODS

=head2 Provided Object Methods

=over 4

=item B< put_fib($value) >

=item B< put_fib(@values) >

Insert one or more values as Fibonacci C1 codes.  Returns 1.

=item B< get_fib() >

=item B< get_fib($count) >

Decode one or more Fibonacci C1 codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=item B< put_fib_c2(@values) >

Insert one or more values as Fibonacci C2 codes.  Returns 1.

Note that the C2 codes are not prefix-free codes, so will not work well with
other codes.  That is, these codes rely on the bit _after_ the code to be a 1
(or the end of the stream).  Other codes may not meet this requirement.

=item B< get_fib_c2() >

=item B< get_fib_c2($count) >

Decode one or more Fibonacci C2 codes from the stream.

=back

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

=item B< get_unary >

=item B< put_string >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item A.S. Fraenkel and S.T. Klein, "Robust Universal Complete Codes for Transmission and Compression", Discrete Applied Mathematics, Vol 64, pp 31-55, 1996.

=item L<http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.37.3064>

Introduces the order C<m=2> Fibonacci codes C1, C2, and C3.  The m=2 C1 codes
are what most people call Fibonacci codes.

=item L<http://en.wikipedia.org/wiki/Fibonacci_coding>

A description of the C<m=2> C1 code.

=item Shmuel T. Klein and Miri Kopel Ben-Nissan, "On the Usefulness of Fibonacci Compression Codes", The Computer Journal, Vol 53, pp 701-716, 2010.

=item L<http://u.cs.biu.ac.il/~tomi/Postscripts/fib-rev.pdf>

More information on Fibonacci codes, including C<mE<gt>2> codes.

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2011 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
