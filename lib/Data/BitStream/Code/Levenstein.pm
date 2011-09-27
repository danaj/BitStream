package Data::BitStream::Code::Levenstein;
BEGIN {
  $Data::BitStream::Code::Levenstein::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Levenstein::VERSION = '0.01';
}

sub _floorlog2_lev {
  my $d = shift;
  my $base = 0;
  $base++ while ($d >>= 1);
  $base;
}

use Mouse::Role;

requires qw(read write get_unary1 put_unary1);

# Levenstein code (also called Levenshtein).
#
# Early variable length code (1968), rarely used.  Compares to Elias Omega.
#
# See:  V.E. Levenstein, "On the Redundancy and Delay of Separable Codes for the Natural Numbers," in Problems of Cybernetics v. 20 (1968), pp 173-179.
#
# Notes:
#   This uses a 1-based unary coding.  This matches the code definition,
#   though is less efficient with most BitStream implementations.
#
#   Given BitStream's 0-based Omega,
#       length(levenstein(k+1)) == length(omega(k))+1   for all k >= 0
#

sub put_levenstein {
  my $self = shift;

  foreach my $v (@_) {
    die "Value must be >= 0" unless $v >= 0;
    if ($v == 0) { $self->write(1, 0); next; }

    # Simpler code:
    # while ( (my $base = _floorlog2($val)) > 0) {
    #   unshift @d, [$base, $val];
    #   $val = $base;
    # }
    # $self->put_unary1(scalar @d + 1);
    # foreach my $aref (@d) {  $self->write( @{$aref} );  }

    my $val = $v;
    my @d;
if (0) {
    while ( (my $base = _floorlog2_lev($val)) > 0) {
      unshift @d, [$base, $val];
      $val = $base;
    }
    $self->put_unary1(scalar @d + 1);
} else {
    # Bundle up groups of 32-bit writes.
    my $cbits = 0;
    my $cword = 0;
    my $C = 1;
    while ( (my $base = _floorlog2_lev($val)) > 0) {
      $C++;
      my $cval = $val & ~(1 << $base);  # erase bit above base
      if (($cbits + $base) >= 32) {
        unshift @d, [$cbits, $cword] if $cbits > 0;
        $cword = $cval;
        $cbits = $base;
      } else {
        $cword |= ($cval << $cbits);
        $cbits += $base;
      }
      $val = $base;
    }
    unshift @d, [$cbits, $cword] if $cbits > 0;;
    $self->put_unary1($C);
}

    foreach my $aref (@d) {  $self->write( @{$aref} );  }
  }
  1;
}

sub get_levenstein {
  my $self = shift;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $C = $self->get_unary1;
    last unless defined $C;
    my $val = 0;
    if ($C > 0) {
      my $N = 1;
      for (1 .. $C-1) {
        $N = (1 << $N) | $self->read($N);
      }
      $val = $N;
    }
    push @vals, $val;
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
