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
# You can optionally put a sub in the first arg.
#
# This array must be sorted and non-negative.

sub put_additive {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;
  my $sub = shift if ref $_[0] eq 'CODE';
  my $p = shift;
  $self->error_code('param', 'p must be an array') unless (ref $p eq 'ARRAY') && scalar @$p >= 1;

  foreach my $val (@_) {
    $self->error_code('zeroval') unless defined $val and $val >= 0;

    # Expand the basis if necessary and possible.
    $sub->($p, $val) if defined $sub  &&  $p->[-1] < $val;
    # Determine how far to look in the basis
    my $maxbasis = 0;
    $maxbasis++ while exists $p->[$maxbasis+1] && $val > $p->[$maxbasis];
    #print "Max basis is $maxbasis, max value: $p->[$maxbasis]\n";
    #print "     basis[$_] = $p->[$_]\n" for (0 .. $maxbasis);

    # Determine the best code to use for this value.  Slow.
    my @best_pair;
    my $best_pair_len = 100000000;
    my $startj = $maxbasis;
    foreach my $i (0 .. $maxbasis) {
      my $pi = $p->[$i];
      # Since $pi is monotonically increasing, $pj starts out large and gets
      # smaller as we search farther in.
      $startj-- while $startj > 0 && ($pi + $p->[$startj]) > $val;
      last if $startj < $i;
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
  my $sub = shift if ref $_[0] eq 'CODE';
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
    my $pi = $p->[$i];
    my $pj = $p->[$j];
    if ( (!defined $pj) && (defined $sub) ) {
      $sub->($p, -$j);   # Generate the basis through j
      $pi = $p->[$i];
      $pj = $p->[$j];
    }
    $self->error_code('overflow') unless defined $pi && defined $pj;
    push @vals, $pi+$pj;
  }
  $self->code_pos_end;
  wantarray ? @vals : $vals[-1];
}


##########  Additive codes using seeds

my $expand_additive_basis = sub {
  my $p = shift;
  my $maxval = shift;

  push @{$p}, 0, 1  unless @{$p};

  # Assume the basis is sorted and complete to $p->[-1].
  my %sumhash;
  my @sums;
  foreach my $b1 (@{$p}) {
    foreach my $b2 (@{$p}) {
      $sumhash{$b1+$b2} = 1;
    }
  }
  my $lastp = $p->[-1];
  delete $sumhash{$_} for (grep { $_ <= $lastp } keys %sumhash);
  @sums = sort { $a <=> $b } keys %sumhash;
  my $n = $lastp;

  while (1) {
    if ($maxval >= 0) {  last if  $maxval < $p->[-1];  }
    else              {  last if -$maxval < scalar @{$p};  }
    $n++;
    if (!@sums || ($sums[0] > $n)) {
      push @{$p}, $n;                               # add $n to basis
      $sumhash{$n+$_} = 1  for @{$p};               # calculate new sums
      delete $sumhash{$n};                          # sums from $n+1 up
      @sums = sort { $a <=> $b } keys %sumhash;
    } else {
      shift @sums if @sums && $sums[0] <= $n;       # remove obsolete sums
      delete $sumhash{$n};
    }
  }
  1;
};

# Give a maximum range and some seeds (even numbers).  You can then take the
# resulting basis and hand it to get_additive() / put_additive().
#
# Examples:
#      99, 8, 10, 16
#     127, 8, 20, 24
#     249, 2, 16, 46
#     499, 2, 34, 82
#     999, 2, 52, 154
sub generate_additive_basis {
  my $self = shift;
  my $max = shift;

  my @basis = (0, 1);
  # Perhaps some checking of defined, even, >= 2, no duplicates.
  foreach my $seed (sort {$a<=>$b} @_) {
    # Expand basis to $seed-1
    $expand_additive_basis->(\@basis, $seed-1) if $seed > ($basis[-1]+1);
    # Add seed to basis
    push @basis, $seed if $seed > $basis[-1];
    last if $seed >= $max;
  }
  $expand_additive_basis->(\@basis, $max) if $max > $basis[-1];
  @basis;
}


# More flexible seeded functions.  These take the seeds and expand the basis
# as needed to construct the desired values.  They also cache the constructed
# bases.

my %_cached_bases;

sub put_additive_seeded {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;
  my $p = shift;
  $self->error_code('param', 'p must be an array') unless (ref $p eq 'ARRAY') && scalar @$p >= 1;

  my $handle = join('-', @{$p});
  if (!defined $_cached_bases{$handle}) {
    my @basis = $self->generate_additive_basis($p->[-1], @{$p});
    $_cached_bases{$handle} = \@basis;
  }
  $self->put_additive($expand_additive_basis, $_cached_bases{$handle}, @_);
}

sub get_additive_seeded {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;
  my $p = shift;
  $self->error_code('param', 'p must be an array') unless (ref $p eq 'ARRAY') && scalar @$p >= 1;

  my $handle = join('-', @$p);
  if (!defined $_cached_bases{$handle}) {
    my @basis = $self->generate_additive_basis($p->[-1], @{$p});
    $_cached_bases{$handle} = \@basis;
  }
  $self->get_additive($expand_additive_basis, $_cached_bases{$handle}, @_);
}


##########  Support code for Goldbach codes

my $expand_primes_sub;
my $prime_test_sub;

# We could also use:
#    Math::Prime::FastSieve
#    Math::Primality
#    Math::Prime::TiedArray
# if we find any of them.  The first two ought to be fast.
if (eval {require Math::Prime::XS; Math::Prime::XS->import(qw(primes is_prime)); 1;}) {
  $expand_primes_sub = sub {
    my $p = shift;
    my $maxval = shift;
    if ($maxval >= 0) {
      push @{$p}, primes($p->[-1]+1, $maxval);
    } else {
      my $maxindex = -$maxval;
      # No direct method, so expand until index reached
      my $curlast = $p->[-1];
      while (!defined $p->[$maxindex]) {
        $curlast = int($curlast * 1.1) + 1000;
        push @{$p}, primes($p->[-1]+1, $curlast);
      }
    }
    1;
  };
  $prime_test_sub = sub { is_prime(shift); };
} else {
  # Next prime code based on Howard Hinnant's Stackoverflow implementation 6.
  # Uses wheel factorization for performance.  The XS code is MUCH faster.

  sub _is_prime {   # Note:  assumes n is not divisible by 2, 3, or 5!
    my $x = shift;
    my $q;
    # Quick loop for small prime divisibility
    foreach my $i (7, 11, 13, 17, 19, 23, 29) {
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);
    }
    # Unrolled mod-30 loop
    my $i = 31;
    while (1) {
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 6;
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 4;
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 2;
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 4;
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 2;
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 4;
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 6;
      $q = int($x/$i); return 1 if $q < $i; return 0 if $x == ($q*$i);  $i += 2;
    }
    1;
  }

  my @_prime_indices = (1, 7, 11, 13, 17, 19, 23, 29);
  sub _next_prime {
    my $x = shift;
    if ($x <= 29) {
      my @small_primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29);
      my $spindex = 0;  $spindex++ while $x > $small_primes[$spindex];
      return $small_primes[$spindex];
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

  $expand_primes_sub = sub {
    my $p = shift;
    my $maxval = shift;
    if ($maxval >= 0) {
      push @{$p}, _next_prime($p->[-1]+2) while $p->[-1] < $maxval;
    } else {
      my $maxindex = -$maxval;
      push @{$p}, _next_prime($p->[-1]+2) while !defined $p->[$maxindex];
    }
    1;
  };

  $prime_test_sub = sub {
    my $x = shift;
    my $q;
    foreach my $i (2, 3, 5) {
      $q = int($x/$i);  return 1 if $q < $i;  return 0 if $x == ($q*$i);
    }
    _is_prime($x);
  };
}


##########  Goldbach G1 codes using the 2N form, and modified for 0-based.

my @_pbasis = (1, 3, 5, 7, 11, 13, 17, 19, 23, 29);

sub put_goldbach_g1 {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;

  $self->put_additive($expand_primes_sub,
                      \@_pbasis,
                      map { ($_+1)*2 } @_);
}

sub get_goldbach_g1 {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;

  my @vals = map { int($_/2)-1 }  $self->get_additive($expand_primes_sub,
                                                      \@_pbasis,
                                                      @_);
  wantarray ? @vals : $vals[-1];
}

##########  Goldbach G2 codes modified for 0-based.
# TODO: These are not working yet

sub put_goldbach_g2 {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;

  foreach my $v (@_) {
    $self->error_code('zeroval') unless defined $v and $v >= 0;

    if ($v == 0) { $self->write(3, 6); next; }
    if ($v == 1) { $self->write(3, 7); next; }

    my $val = $v+1;

    # Expand prime list as needed
    $expand_primes_sub->(\@_pbasis, $val) if $_pbasis[-1] < $val;

    # Prime
    if (( $val > 2) && $prime_test_sub->($val)) {
      my $spindex = 0;  $spindex++ while $val > $_pbasis[$spindex];
print "> $val is prime, encode as ", $spindex+1, " . 1\n";
      $self->put_gamma($spindex+1);
      $self->write(1, 1);
      next;
    }

    # Odd integer.
    if ( ($val % 2) == 1 ) {
print "> $val is odd, encode as 1 . encode(", $val-1, ")\n";
      $self->write(1, 1);
      $val--;
    }


    # Encode the even value $val as the sum of two primes
    my $p = \@_pbasis;
    my $maxbasis = 0;
    $maxbasis++ while exists $p->[$maxbasis+1] && $val > $p->[$maxbasis];
    #print "Max basis is $maxbasis, max value: $p->[$maxbasis]\n";
    #print "     basis[$_] = $p->[$_]\n" for (0 .. $maxbasis);

    # Determine the best code to use for this value.  Slow.
    my @best_pair;
    my $best_pair_len = 100000000;
    my $startj = $maxbasis;
    foreach my $i (0 .. $maxbasis) {
      my $pi = $p->[$i];
      # Since $pi is monotonically increasing, $pj starts out large and gets
      # smaller as we search farther in.
      $startj-- while $startj > 0 && ($pi + $p->[$startj]) > $val;
      last if $startj < $i;
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
    $self->error_code('range', $v) unless @best_pair;
print "> $v is even, encoded as $p->[$best_pair[0]] + $p->[$best_pair[1]], indices $best_pair[0],$best_pair[1]\n";
    $best_pair[0]++;
    $self->put_gamma(@best_pair);
  }
  1;
}

sub get_goldbach_g2 {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;

  my @vals = map { int($_/2)-1 }  $self->get_additive($expand_primes_sub, \@_pbasis, @_);
  wantarray ? @vals : $vals[-1];
}



##########  Example of using a tied array

#package Data::BitStream::Code::Additive::PrimeArray;
#use Tie::Array;

# ... _isprime() and _next_prime()

#sub TIEARRAY {
#  my $class = shift;
#  if (@_) {
#    croak "usage: tie ARRAY, '" . __PACKAGE__ . "";
#  }
#  return bless {
#    ARRAY => [1, 3, 5, 7, 11, 13, 17, 19, 23, 29],
#  }, $class;
#}
#sub STORE { confess "You cannot write to the prime array"; }
#sub DELETE { confess "You cannot write to the prime array"; }
#sub STORESIZE {
#  my $self = shift;
#  my $count = shift;
#  my $cursize = $self->FETCHSIZE();
#  my $curprime = $self->{ARRAY}->[$cursize-1];
#  if ($count > $cursize) {
#    foreach my $i ($cursize .. $count-1) {
#      $curprime = _next_prime($curprime+2);
#      $self->{ARRAY}->[$i] = $curprime;
#    }
#  } else {
#    foreach (0 .. $cursize - $count - 2 ) {
#      pop @{$self->{ARRAY}};
#    }
#  }
#}
#sub FETCH {
#  my $self = shift;
#  my $index = shift;
#  $self->STORESIZE($index+1) if $index >= scalar @{$self->{ARRAY}};
#  $self->{ARRAY}->[$index];
#}
#sub FETCHSIZE {
#  my $self = shift;
#  scalar @{$self->{ARRAY}};
#}
#sub EXISTS {
#  my $self = shift;
#  my $index = shift;
#  $self->STORESIZE($index+1) unless exists $self->{ARRAY}->[$index];
#  1;
#}
#sub EXTEND {
#  my $self = shift;
#  my $count = shift;
#  $self->STORESIZE( $count );
#}
#
#package Data::BitStream::Code::Additive;
#
#my @_prime_basis;
#tie @_prime_basis, 'Data::BitStream::Code::Additive::PrimeArray';
#
#sub put_goldbach_g1 {
#  my $self = shift;
#  $self->error_stream_mode('write') unless $self->writing;
#
#  $self->put_additive(\@_prime_basis, map { ($_+1)*2 } @_);
#}
#sub get_goldbach_g1 {
#  my $self = shift;
#  $self->error_stream_mode('read') if $self->writing;
#
#  my @vals = map { int($_/2)-1 }  $self->get_additive(\@_prime_basis, @_);
#  wantarray ? @vals : $vals[-1];
#}

##########  End of tied array example

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

If you use the Goldbach codes for inputs more than ~1000, I highly recommend
installing L<Math::Prime::XS> for better performance.

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

You can set up a tied array, and example code exists in the source for this.
In general this will be slower than using a native array plus expansion subs.

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item L<Data::BitStream::Code::Fibonacci>

=item L<Math::Prime::XS>

=item Peter Fenwick, "Variable-Length Integer Codes Based on the Goldbach Conjecture, and Other Additive Codes", IEEE Trans. Information Theory 48(8), pp 2412-2417, Aug 2002.

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2012 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
