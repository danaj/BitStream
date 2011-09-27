package Data::BitStream::Code::Delta;
BEGIN {
  $Data::BitStream::Code::Delta::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Delta::VERSION = '0.01';
}

use Mouse::Role;

requires 'maxbits', 'read', 'write', 'put_gamma', 'get_gamma';

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
