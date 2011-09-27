package Data::BitStream::Code::Baer;
BEGIN {
  $Data::BitStream::Code::Baer::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Baer::VERSION = '0.01';
}

use Mouse::Role;

requires 'read', 'write', 'put_unary', 'get_unary';

# Baer codes.
#
# Used for efficiently encoding data with a power law distribution.
# Compare to the Boldi-Vigna Zeta codes.
#
# See:  Michael B. Baer, "Prefix Codes for Power Laws," in IEEE International Symposium on Information Theory 2008 (ISIT 2008), pp 2464-2468, Toronto ON.
# https://hkn.eecs.berkeley.edu/~calbear/research/ISITuni.pdf

sub put_baer {
  my $self = shift;
  my $k = shift;
  die "invalid parameters" if ($k > 32) || ($k < -32);
  my $mk = ($k < 0) ? int(-$k) : 0;

  foreach my $v (@_) {
    if ($v < $mk) {
      $self->put_unary1($v);
      next;
    }
    my $val = ($k==0)  ?  $v+1  :  ($k < 0)  ?  $v-$mk+1  :  1+($v>>$k);
    my $C = 0;
    my $postword = 0;
    while ($val >= 4) {
      if (($val & 1) == 0) { $val = ($val - 2) >> 1; }
      else                 { $val = ($val - 3) >> 1; $postword |= (1 << $C); }
      $C++;
    }
    $self->put_unary1($C + $mk);
    if    ($val == 1) { $self->write(1, 0); }
    else              { $self->write(2, $val); }
    $self->write($C, $postword) if $C > 0;
    $self->write($k, $v) if $k > 0;
  }
  1;
}

sub get_baer {
  my $self = shift;
  my $k = shift;
  die "invalid parameters" if ($k > 32) || ($k < -32);
  my $mk = ($k < 0) ? int(-$k) : 0;

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $C = $self->get_unary1;
    last unless defined $C;
    if ($C < $mk) {
      push @vals, $C;
      next;
    }
    $C -= $mk;
    my $v = $self->read(1);
    my $val = ($v == 0)  ?  1  :  2 + $self->read(1);
    #while ($C-- > 0) {  $val = 2 * $val + 2 + $self->read(1);  }
    $val = ($val << $C) + ((1 << ($C+1)) - 2) + $self->read($C)  if $C > 0;
    $val += $mk;
    if ($k > 0) { $val = 1 + ( (($val-1) << $k) | $self->read($k) ); }
    push @vals, $val-1;
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
