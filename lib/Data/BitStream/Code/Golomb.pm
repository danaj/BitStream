package Data::BitStream::Code::Golomb;
BEGIN {
  $Data::BitStream::Code::Golomb::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Golomb::VERSION = '0.02';
}

use Mouse::Role;

requires 'read', 'write', 'put_unary', 'get_unary';

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
