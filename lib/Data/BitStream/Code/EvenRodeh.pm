package Data::BitStream::Code::EvenRodeh;
BEGIN {
  $Data::BitStream::Code::EvenRodeh::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::EvenRodeh::VERSION = '0.01';
}

sub _floorlog2_er {
  my $d = shift;
  my $base = 0;
  $base++ while ($d >>= 1);
  $base;
}
sub _dec_to_bin_er {
  my $v =  ($_[0] > 32)  ?  pack("Q", $_[1])  :  pack("L", $_[1]);
  scalar reverse unpack("b$_[0]", $v);
}

use Mouse::Role;

requires qw(read write put_string);

# Even-Rodeh Code
#
# Similar in many ways to the Elias Omega code.
#
# Very rarely used code.
#
# See:  S. Even, M. Rodeh, “Economical Encoding of Commas Between Strings”, Comm ACM, Vol 21, No 4, pp 315–317, April 1978.
#
# See: Peter Fenwick, "Punctured Elias Codes for variable-length coding of the integers", Technical Report 137, Department of Computer Science, University of Auckland, December 1996


sub put_evenrodeh {
  my $self = shift;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    if ($val <= 3) {
      $self->write(3, $val);
    } else {
      my $str = '0';
      my $v = $val;
      do {
        my $base = _floorlog2_er($v)+1;
        $str = _dec_to_bin_er($base, $v) . $str;
        $v = $base;
      } while ($v > 3);
      $self->put_string($str);
    }
  }
  1;
}

sub get_evenrodeh {
  my $self = shift;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $val = $self->read(3);
    last unless defined $val;
    if ($val > 3) {
      my $first_bit;
      while ($first_bit = $self->read(1)) {
        $val = (1 << ($val-1)) | $self->read($val-1);
      }
    }
    push @vals, $val;
  }

  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
