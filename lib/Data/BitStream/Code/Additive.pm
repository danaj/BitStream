package Data::BitStream::Code::Additive;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::Escape::AUTHORITY = 'cpan:DANAJ';
  $Data::BitStream::Code::Escape::VERSION = '0.01';
}

our $CODEINFO = { package   => __PACKAGE__,
                  name      => 'Additive',
                  universal => 0,
                  params    => 1,
                  encodesub => sub {shift->put_additive([split(',',shift)], @_)},
                  decodesub => sub {shift->get_additive([split(',',shift)], @_)}, };

#use List::Util qw(max);
use Mouse::Role;
requires qw(read write);

sub _additive_gamma_len {
  my $n = shift;
  my $gammalen = 1;
  $gammalen += 2 while $n >= ((2 << ($gammalen>>1))-1);
  $gammalen;
}

# 2-ary additive code.
#
# The parameter comes in as an array.  Hence:
#
# $stream->put_additive( [0,1,3,5,7,8,10,16,22,28,34,40], $value );
#
# $stream->get_additive( [0,1,3,5,7,8,10,16,22,28,34,40], $value );
#
# This array must be sorted and non-negative.

sub put_additive {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;
  my $p = shift;
  $self->error_code('param', 'p must be an array') unless (ref $p eq 'ARRAY') && scalar @$p >= 1;

  foreach my $val (@_) {
    $self->error_code('zeroval') unless defined $val and $val >= 0;

    # Determine how far to look in the basis
    my $maxbasis = 0;
    $maxbasis++ while ($maxbasis < $#{$p} && $val > $p->[$maxbasis]);
    #print "Max basis is $maxbasis, max value: $p->[$maxbasis]\n";

    # Determine the best code to use for this value.
    # Very slow, especially if the basis is dense.
    my @best_pair;
    my $best_pair_len = 100000000;
    foreach my $i (0 .. $maxbasis) {
      my $pi = $p->[$i];
      my $startj = $i;
      foreach my $inc (10000,1000,100,10) {
        $startj += $inc while defined $p->[$startj+$inc]  &&  ($pi + $p->[$startj+$inc]) <= $val;
      }
      foreach my $j ($startj .. $maxbasis) {
        my $pj = $p->[$j];
        last if ($pi+$pj) > $val;
        if (($pi+$pj) == $val) {
          my $glen = _additive_gamma_len($i) + _additive_gamma_len($j-$i);
          #print "poss: $p->[$i] + $p->[$j] = $val.  Indices $i,$j.  Pair $i, ", $j-$i, ".  Len $glen.\n";
          if ($glen < $best_pair_len) {
            @best_pair = ($i,$j-$i);
            $best_pair_len = $glen;
          }
        }
      }
    }
    $self->error_code('range', $val) unless @best_pair;
    $self->put_gamma(@best_pair);
  }
  1;
}

sub get_additive {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;
  my $p = shift;
  $self->error_code('param', 'p must be an array') unless (ref $p eq 'ARRAY') && scalar @$p >= 1;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  $self->code_pos_start('Additive');
  while ($count-- > 0) {
    $self->code_pos_set;
    # Read the two gamma-encoded values
    my ($i,$j) = $self->get_gamma(2);
    last unless defined $i;
    $self->error_off_stream unless defined $j;
    $j += $i;
    $self->error_code('overflow') unless defined $p->[$i] && defined $p->[$j];
    push @vals, $p->[$i] + $p->[$j];
  }
  $self->code_pos_end;
  wantarray ? @vals : $vals[-1];
}


# Give a maximum range and some seeds (even numbers).
# Examples:
#      99, 8, 10, 16
#     127, 8, 20, 24
#     249, 2, 16, 46
#     499, 2, 34, 82
#     999, 2, 52, 154
sub generate_additive_basis {
  my $self = shift;
  my $max = shift;
  # Perhaps some checking of defined, even, >= 2, no duplicates.
  my @basis = (0, 1, @_);

  my @sums;
  foreach my $b1 (@basis) {
    foreach my $b2 (@basis) {
      push @sums, $b1+$b2;
    }
  }
  @sums = sort { $a <=> $b } @sums;
  #shift @sums while @sums && $sums[0] < 2;

  foreach my $n (1 .. $max) {
    if (@sums && ($sums[0] <= $n)) {
      # We can already make this number from our sums.  Remove.
      shift @sums while @sums && $sums[0] <= $n;
    } else {
      # Can't make this number, add it to the basis
      push @sums, $n+$_ for @basis;                  # Add all new sums
      @sums = sort { $a <=> $b } @sums;              # Sort sums
      shift @sums while @sums && $sums[0] <= $n;     # remove obsolete sums
      push @basis, $n;                               # add $n to basis
    }
  }
  @basis = sort { $a <=> $b } @basis;
  @basis;
}


##########  Support code for Goldbach codes

# Next prime code based on Howard Hinnant's Stackoverflow implementation 6.
# This uses wheel factorization to speed things up.

#my @_small_primes_check = (7, 11, 13, 17, 19, 23, 29);
sub _is_prime {   # Note:  assumes n is not divisible by 2, 3, or 5!
  my $x = shift;
  my $q;
  # Quick loop for small prime divisibility
  foreach my $i (7, 11, 13, 17, 19, 23, 29) {
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);
  }
  # Unrolled mod-30 loop
  my $i = 31;
  while (1) {
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 6;
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 4;
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 2;
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 4;
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 2;
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 4;
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 6;
    $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);  $i += 2;
  }
  1;
}

my @_small_primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29);
my @_prime_indices = (1, 7, 11, 13, 17, 19, 23, 29);
sub _next_prime {
  my $x = shift;
  if ($x <= $_small_primes[-1]) {
    my $spindex = 0;
    $spindex++ while $x > $_small_primes[$spindex];
    return $_small_primes[$spindex];
  }
  # Search starting at L*k0 + indices[in]
  my $L = 30;
  my $k0 = int($x/$L);
  my $in = 0;  $in++ while ($x-$k0*$L) > $_prime_indices[$in];
  my $n = $L * $k0 + $_prime_indices[$in];
  my $M = scalar @_prime_indices;
  while (!_is_prime($n)) {
    if (++$in == $M) {  $k0++; $in = 0;  }
    $n = $L * $k0 + $_prime_indices[$in];
  }
  $n;
}

my @_pbasis = (1, 3, 5, 7, 11, 13, 17, 19, 23, 29);

# G1 codes using the 2N form, and modified for 0-based.
#
# An arguably better way to handle this would generate the basis as needed.
# While the prime generator is pretty fast code, it still takes a long time
# to generate 100k or more primes using Perl.

sub put_goldbach_g1 {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;
  my $maxval = shift;
  $maxval = ($maxval + 1) * 2;

  # Determine max value, ensure basis is complete to that value
  #my $maxval = max @_;
  push @_pbasis, _next_prime($_pbasis[-1]+2) while $_pbasis[-1] < $maxval;

  # 0 -> 1*2 -> 2
  # 1 -> 2*2 -> 4
  # 2 -> 3*2 -> 6
  $self->put_additive(\@_pbasis, map { ($_+1)*2 } @_);
}

sub get_goldbach_g1 {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;
  my $maxval = shift;
  $maxval = ($maxval + 1) * 2;

  push @_pbasis, _next_prime($_pbasis[-1]+2) while $_pbasis[-1] < $maxval;

  # 2-> 1-1 -> 0
  # 4-> 2-1 -> 1
  # 6-> 3-1 -> 1
  my @vals = map { int($_/2)-1 }  $self->get_additive(\@_pbasis, @_);
  wantarray ? @vals : $vals[-1];
}

# TODO:  G2 codes

# TODO:  Ulam codes



no Mouse::Role;
1;

# ABSTRACT: A Role implementing Additive codes

=pod

=head1 NAME

Data::BitStream::Code::Additive - A Role implementing Additive codes

=head1 VERSION

version 0.01

=head1 DESCRIPTION

A role written for L<Data::BitStream> that provides get and set methods for
Additive codes.  The role applies to a stream object.

B<TODO>: Add description

=head1 EXAMPLES

  use Data::BitStream;
  my $stream = Data::BitStream->new;
  my @array = (4, 2, 0, 3, 7, 72, 0, 1, 13);
  my @basis = (0,1,3,5,7,8,10,16,22,28,34,40,46,52,58,64,70,76,82,88,94);

  $stream->put_additive( \@basis, @array );
  $stream->rewind_for_read;
  my @array2 = $stream->get_additive( \@basis, -1);

  # @array equals @array2

=head1 METHODS

=head2 Provided Object Methods

=over 4

=item B< put_additive([@basis], $value) >

=item B< put_additive([@basis], @values) >

Insert one or more values as Additive codes.  Returns 1.

=item B< get_additive([@basis]) >

=item B< get_additive([@basis], $count) >

Decode one or more Additive codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=back

=head2 Parameters

The basis for the Additive code is passed as a array reference.

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item L<Data::BitStream::Code::Fibonacci>

=item Peter Fenwick, "Variable-Length Integer Codes Based on the Goldbach Conjecture, and Other Additive Codes", IEEE Trans. Information Theory 48(8), pp 2412-2417, Aug 2002.

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2012 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
