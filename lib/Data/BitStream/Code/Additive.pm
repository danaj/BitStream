package Data::BitStream::Code::Additive;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::Escape::AUTHORITY = 'cpan:DANAJ';
  $Data::BitStream::Code::Escape::VERSION = '0.01';
}

our $CODEINFO = [ { package   => __PACKAGE__,
                    name      => 'Additive',
                    universal => 0,
                    params    => 1,
                    encodesub => sub {shift->put_additive_seeded([split('-',shift)], @_)},
                    decodesub => sub {shift->get_additive_seeded([split('-',shift)], @_)},
                  },
                  { package   => __PACKAGE__,
                    name      => 'GoldbachG1',
                    universal => 1,
                    params    => 0,
                    encodesub => sub {shift->put_goldbach_g1(@_)},
                    decodesub => sub {shift->get_goldbach_g1(@_)},
                  },
                  { package   => __PACKAGE__,
                    name      => 'GoldbachG2',
                    universal => 1,
                    params    => 0,
                    encodesub => sub {shift->put_goldbach_g2(@_)},
                    decodesub => sub {shift->get_goldbach_g2(@_)},
                  },
                ];



#use List::Util qw(max);
use Mouse::Role;
requires qw(read write);

sub _additive_gamma_len {
  my $n = shift;
  my $gammalen = 1;
  $gammalen += 2 while $n >= ((2 << ($gammalen>>1))-1);
  $gammalen;
}

# Determine the best 2-ary sum over the basis p to use for this value.
sub _find_best_pair {
  my($p, $val, $pairsub) = @_;

  # Determine how far to look in the basis
  my $maxbasis = 0;
  $maxbasis+=100 while exists $p->[$maxbasis+101] && $val > $p->[$maxbasis+100];
  $maxbasis++    while exists $p->[$maxbasis+  1] && $val > $p->[$maxbasis];

  my @best_pair;
  my $best_pair_len = 100000000;
  my $i = 0;
  my $j = $maxbasis;
  while ($i <= $j) {
    my $pi = $p->[$i];
    my $pj = $p->[$j];
    my $sum = $pi + $pj;
    if    ($sum < $val) {  $i++;  }
    elsif ($sum > $val) {  $j--;  }
    else {
      my($p1, $p2) = $pairsub->($i, $j);  # How i,j are stored
      my $glen = _additive_gamma_len($p1) + _additive_gamma_len($p2);
      #print "poss: $pi + $pj = $val.  Indices $i,$j.  Pair $p1,$p2.  Len $glen.\n";
      if ($glen < $best_pair_len) {
        @best_pair = ($p1, $p2);
        $best_pair_len = $glen;
      }
      $i++;
    }
  }
  @best_pair;
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

    my @best_pair = _find_best_pair($p, $val,
                       sub { my $i = shift; my $j = shift;  ($i, $j-$i);  } );

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
    if ($maxval >= 0) {  last if  $maxval <= $n;  }
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

# Performance:
#
#    1. Data::BitStream::XS
#
#       Whether used directly or seamlessly routed via BLVec, this is by far
#       the fastest solution.  20-100x faster than the others.  Parts:
#
#        - fast prime basis formation (about 2x for large number encoding).
#
#        - fast best-pair search (huge speedup for large number encoding).
#
#        - generic coding speedup similar to XS effect on other codes.
#
#    2. Math::Prime::XS or another XS module from CPAN.
#
#       About a 2x speedup for large numbers (e.g. >100k), almost no change
#       for smaller (e.g. less than 64k) numbers.  This radically speeds up
#       the Goldbach basis generation, but does nothing for the best-pair
#       search.
#
#    3. Pure Perl (this module)
#
# Searching for all sum pairs through a large array (e.g. 1.5M primes for
# n=10_000_000) is not going to be very fast unless a different implementation
# is used (massivily parallel such as GPU would map well, as would using
# extra memory to store the best codes and working sums).  If encoding speed
# is a goal, then another code is recommended.
#
# In terms of raw performance generating primes the ordering on my machine:
#    984/s  Math::Prime::XS
#    165/s  Data::BitStream::XS
#      7/s  Pure Perl
#      1/s  Math::Primality
# noting that Math::Primality is really specializing in very large numbers,
# and that MPXS is sieving while the others are walking primes.  Sieving takes
# extra memory and will be less efficient to add one more number at the end,
# but it is very good when adding many primes, as the performance above shows.
#
# Math::Prime::FastSieve is claimed to be faster than Math::Prime::XS.  It
# doesn't build on my machine, and the interface doesn't seem to map well to
# our usage.  I don't think the prime generation is a bottleneck once we've
# gone to any of the faster implementations.  At that point the best-pair
# search is the time consumer.

if (eval {require Math::Prime::XS; Math::Prime::XS->import(qw(primes is_prime)); 1;}) {
  $expand_primes_sub = sub {
    my $p = shift;
    my $maxval = shift;

    if ($maxval < 0) {     # We need $p->[-$maxval] defined.
      # Inequality:  p_n  <  n*ln(n)+n*ln(ln(n)) for n >= 6
      my $n = ($maxval > -6)  ?  6  :  -$maxval;
      $n++;   # Because we skip 2 in our basis.
      $maxval = int($n * log($n) + $n * log(log($n))) + 1;
    }

    # We want to ensure there is a prime >= $maxval on our list.
    # Use maximal gap, so this loop ought to run exactly once.
    my $adder = ($maxval <= 0xFFFFFFFF)  ?  336  :  2000;
    while ($p->[-1] < $maxval) {
      push @{$p}, primes($p->[-1]+1, $maxval+$adder);
      $adder *= 2;  # Ensure success
    }
    1;
  };
  $prime_test_sub = sub { is_prime(shift); };
} elsif (eval {require Data::BitStream::XS; Data::BitStream::XS->import(qw(next_prime is_prime)); 1;}) {
  # Just in case we find a newer version of DBXS but are still running this
  # code instead of using the Goldbach methods that it has.
  $expand_primes_sub = sub {
    my $p = shift;
    my $maxval = shift;
    if ($maxval >= 0) {
      push @{$p}, next_prime($p->[-1]) while $p->[-1] < $maxval;
    } else {
      my $maxindex = -$maxval;
      push @{$p}, next_prime($p->[-1]) while !defined $p->[$maxindex];
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

  # Return the next prime larger than some integer.
  # Works just like Math::Primality::next_prime() and DBXS::next_prime().
  my @_prime_indices = (1, 7, 11, 13, 17, 19, 23, 29);
  sub _next_prime {
    my $x = shift;
    if ($x <= 30) {
      my @small_primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31);
      my $spindex = 0;  $spindex++ while $x >= $small_primes[$spindex];
      return $small_primes[$spindex];
    }
    $x += 1;
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
      push @{$p}, _next_prime($p->[-1]) while $p->[-1] < $maxval;
    } else {
      my $maxindex = -$maxval;
      push @{$p}, _next_prime($p->[-1]) while !defined $p->[$maxindex];
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

sub put_goldbach_g2 {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;

  foreach my $v (@_) {
    $self->error_code('zeroval') unless defined $v and $v >= 0;

    if ($v == 0) { $self->write(3, 6); next; }
    if ($v == 1) { $self->write(3, 7); next; }

    my $val = $v+1;     # $val >= 3    (note ~0 will not encode)

    # Expand prime list as needed
    $expand_primes_sub->(\@_pbasis, $val) if $_pbasis[-1] < $val;
    $self->error_code('assert', "Basis not expanded to $val") unless $_pbasis[-1] >= $val;

    # Check to see if $val is prime
    if ( (($val%2) != 0) && (($val%3) != 0) ) {
      # Not a multiple of 2 or 3, so look for it in _pbasis
      my $spindex = 0;
      $spindex += 200 while exists $_pbasis[$spindex+200]
                         && $val > $_pbasis[$spindex+200];
      $spindex++ while $val > $_pbasis[$spindex];
      if ($val == $_pbasis[$spindex]) {
        # We store the index (noting that value 3 is index 1 for us)
        $self->put_gamma($spindex);
        $self->write(1, 1);
        next;
      }
    }

    # Odd integer.
    if ( ($val % 2) == 1 ) {
      $self->write(1, 1);
      $val--;
    }

    # Encode the even value $val as the sum of two primes
    my @best_pair = _find_best_pair(\@_pbasis, $val,
                       sub { my $i = shift; my $j = shift;  ($i+1,$j-$i+1); } );

    $self->error_code('range', $v) unless @best_pair;
    $self->put_gamma(@best_pair);
  }
  1;
}

sub get_goldbach_g2 {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  my $p = \@_pbasis;
  $self->code_pos_start('Goldbach G2');
  while ($count-- > 0) {
    $self->code_pos_set;

    # Look at the start 3 values
    my $look = $self->read(3, 'readahead');
    last unless defined $look;

    if ($look == 6) {  $self->skip(3);  push @vals, 0;  next;  }
    if ($look == 7) {  $self->skip(3);  push @vals, 1;  next;  }

    my $val = -1;   # Take into account the +1 for 1-based

    if ($look >= 4) {  # First bit is a 1  =>  Odd number
      $val++;
      $self->skip(1);
    }

    my ($i,$j) = $self->get_gamma(2);
    $self->error_off_stream unless defined $i && defined $j;

    my $pi;
    my $pj;
    if ($j == 0) {
      $expand_primes_sub->(\@_pbasis, -$i) unless defined $p->[$i];
      $pi = $p->[$i];
      $pj = 0;
    } else {
      $i = $i - 1;
      $j = $j + $i - 1;
      $expand_primes_sub->(\@_pbasis, -$j) unless defined $p->[$j];
      $pi = $p->[$i];
      $pj = $p->[$j];
    }
    $self->error_code('overflow') unless defined $pi && defined $pj;

    push @vals, $val+$pi+$pj;
  }
  $self->code_pos_end;
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
  use Data::BitStream::Code::Additive;
  my $stream = Data::BitStream->new;
  Data::BitStream::Code::Additive->meta->apply($stream);

  my @array = (4, 2, 0, 3, 7, 72, 0, 1, 13);

  $stream->put_goldbach_g1( @array );
  $stream->rewind_for_read;
  my @array2 = $stream->get_goldbach_g1( -1 );

  my @seeds = (2, 16, 46);
  $stream->erase_for_write;
  $stream->put_additive_seeded( \@seeds, @array );
  $stream->rewind_for_read;
  my @array2 = $stream->get_additive_seeded( \@seeds, -1 );

  my @basis = (0,1,3,5,7,8,10,16,22,28,34,40,46,52,58,64,70,76,82,88,94);
  $stream->erase_for_write;
  $stream->put_additive( \@basis, @array );
  $stream->rewind_for_read;
  my @array2 = $stream->get_additive( \@basis, -1 );
=head1 METHODS

=head2 Provided Object Methods

=over 4

=item B< put_goldbach_g1($value) >

=item B< put_goldbach_g1(@values) >

Insert one or more values as Goldbach G1 codes.  Returns 1.
The Goldbach conjecture claims that any even number is the sum of two primes.
This coding finds, for any value, the shortest pair of gamma-encoded prime
indices that form C<2*($value+1)>.

=item B< get_goldbach_g1() >

=item B< get_goldbach_g1($count) >

Decode one or more Goldbach G1 codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=item B< put_goldbach_g2($value) >

=item B< put_goldbach_g2(@values) >

Insert one or more values as Goldbach G2 codes.  Returns 1.  Uses a different
coding than G1 that should yield slightly smaller codes for large values.

=item B< get_goldbach_g2() >

=item B< get_goldbach_g2($count) >

Decode one or more Goldbach G2 codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=item B< put_additive_seeded(\@seeds, $value) >

=item B< put_additive_seeded(\@seeds, @values) >

Insert one or more values as Additive codes.  Returns 1.  Arbitrary values
may be given as input, with the basis constructed as needed using the seeds.
The seeds should be sorted and not contain duplicates.  They will typically
be even numbers.  Examples include
C<[2,16,46]>, C<[2,34,82]>, C<[2,52,154,896]>.  Each generated basis is
cached, so successive put/get calls using the same seeds will run quickly.

=item B< get_additive_seeded(\@seeds) >

=item B< get_additive_seeded(\@seeds, $count) >

Decode one or more Additive codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=item B< generate_additive_basis($maxval, @seeds) >

Construct an additive basis from C<0> to C<$maxval> using the given seeds.
This allows construction of bases as shown in Fenwick's 2002 paper.  The
basis is returned as an array.  The bases will be identical to those used
with the C<get/put_additive_seeded> routines, though the latter allows the
basis to be expanded as needed.

=item B< put_additive(\@basis, $value) >

=item B< put_additive(\@basis, @values) >

Insert one or more values as 2-ary additive codes.  Returns 1.  An arbitrary
basis to be used is provided.  This basis should be sorted and consist of
non-negative integers.  For each value, all possible pairs C<(i,j)> are found
where C<i + j = value>, with the pair having the smallest sum of Gamma
encoding for C<i> and C<j> being chosen.  This pair is then Gamma encoded.
If no two values in the basis sum to the requested value, a range error results.

=item B< put_additive(sub { ... }, \@basis, @values) >

Insert one or more values as 2-ary additive codes, as above.  The provided
subroutine is used to expand the basis as needed if a value is too large for
the current basis.  As before, the basis should be sorted and consist of
non-negative integers.  It is assumed the basis is complete up to the last
element (that is, the basis will only be expanded).  The argument to the sub
is a reference to the basis array and a value.  When returned, the last entry
of the basis should be greater than or equal to the value.

=item B< get_additive(\@basis) >

=item B< get_additive(\@basis, $count) >

Decode one or more 2-ary additive codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=item B< get_additive(sub { ... }, \@basis, @values) >

Decode one or more values as 2-ary additive codes, as above.  The provided
subroutine is used to expand the basis as needed if an index is too large for
the current basis.  The argument to the sub is a reference to the basis array
and a negative index.  When returned, index C<-$index> of the basis must be
defined as a non-negative integer.

=back

=head2 Parameters

Both the basis and seed arrays are passed as array references.  The basis
array may be modified if a sub is given (since its job is to expand the basis).

You can set up a tied array, and example code exists in the source for this.
In general this will be slower than using a native array plus expansion subs.

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

=item B< get_gamma >

=item B< put_gamma >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item L<Data::BitStream::Code::Fibonacci>

=item L<Data::BitStream::Code::Gamma>

=item L<Math::Prime::XS>

=item Peter Fenwick, "Variable-Length Integer Codes Based on the Goldbach Conjecture, and Other Additive Codes", IEEE Trans. Information Theory 48(8), pp 2412-2417, Aug 2002.

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2012 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
