package Data::BitStream::Code::ExponentialGolomb;
BEGIN {
  $Data::BitStream::Code::ExponentialGolomb::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::ExponentialGolomb::VERSION = '0.01';
}

use Mouse::Role;

requires 'read', 'write', 'put_gamma', 'get_gamma';

# The more generic version of this is GammaGolomb, which takes a parameter M
# that indicates the base.  It is basically Golomb codes using Gamma instead
# of Unary to encode the quotient.
#
# This version is to GammaGolomb as Rice is to Golomb.  It takes a parameter k
# where m=2^k.  So:
#
#        ExponentialGolomb(k)  <=>  GammaGolomb(2^k)
#                     Rice(k)  <=>  Golomb(2^k)
#
# The simplified versions are provided partly for efficiency, but mostly
# because they are more commonly used.

sub put_expgolomb {
  my $self = shift;
  my $k = shift;
  die "k must be >= 0" unless $k >= 0;

  return $self->put_gamma(@_) if $k == 0;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    my $q = $val >> $k;
    my $r = $val - ($q << $k);
    $self->put_gamma($q);
    $self->write($k, $r);
  }
  1;
}
sub get_expgolomb {
  my $self = shift;
  my $k = shift;
  die "k must be >= 0" unless $k >= 0;
  return $self->get_gamma(@_) if $k == 0;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $val = $self->get_gamma();
    last unless defined $val;
    if ($k > 0) {
      $val <<= $k;
      $val += $self->read($k);
    }
    push @vals, $val;
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
