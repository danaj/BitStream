package Data::BitStream::Code::Flag;
BEGIN {
  $Data::BitStream::Code::Flag::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Flag::VERSION = '0.01';
}

use Mouse::Role;

requires qw(read write);

# Flag code.  Similar to Start-Step-Stop codes, but rather than encoding the
# prefix in unary, we read a number of bits and go to the next if we have read
# the maximum value (binary all ones).
#
# The parameter comes in as an array.  Hence:
#
# $stream->put_flag( [3,5,9,32], $value );
#
# $stream->get_flag( [3,5,9,32], $value );
#
# A parameter of undef means maxbits.

sub put_flag {
  my $self = shift;
  my $p = shift;
  die "p must be an array" unless (ref $p eq 'ARRAY') && scalar @$p >= 1;

  my @parray = @$p;
  my $maxbits = $self->maxbits;
  map {
        $_ = $maxbits if (!defined $_) || ($_ > $maxbits);
        die "invalid parameters" if $_ <= 0;
      } @parray;

  foreach my $val (@_) {
    my @bitarray = @parray;
    my $bits = shift @bitarray;
    my $min = 0;
    my $maxval = ($bits < $maxbits) ? (1<<$bits)-2 : ~0-1;
    my $onebits = 0;

    #print "[$onebits]: $bits bits  range $min - ", $min+$maxval, "\n";
    while ( ($val-$min) > $maxval ) {
      $onebits += $bits;
      $min += $maxval+1;
      die "Cannot encode $val" if scalar @bitarray == 0;
      $bits = shift @bitarray;
      $maxval = ($bits < $maxbits) ? (1<<$bits)-2 : ~0-1;
      #print "[$onebits]: $bits bits  range $min - ", $min+$maxval, "\n";
    }
    while ($onebits > 32) { $self->write(32, 0xFFFFFFFF); $onebits -= 32; }
    if ($onebits > 0)     { $self->write($onebits, 0xFFFFFFFF); }
    $self->write($bits, $val-$min) if $bits > 0;
  }
  1;
}

sub get_flag {
  my $self = shift;
  my $p = shift;
  die "p must be an array" unless (ref $p eq 'ARRAY') && scalar @$p >= 1;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @parray = @$p;
  my $maxbits = $self->maxbits;
  map {
        $_ = $maxbits if (!defined $_) || ($_ > $maxbits);
        die "invalid parameters" if $_ <= 0;
      } @parray;

  my @vals;
  while ($count-- > 0) {
    my @bitarray = @parray;
    my($min,$maxval,$bits,$v) = (-1,0,0,0);
    do {
      $min += $maxval+1;
      die "invalid encoding" if scalar @bitarray == 0;
      $bits = shift @bitarray;
      $maxval = ($bits < $maxbits) ? (1<<$bits)-2 : ~0-1;
      $maxval++ if scalar @bitarray == 0;
      $v = $self->read($bits);
      last unless defined $v;
      #print "read $bits bits, maxval = $maxval, v = $v, val = ", $v+$min, "\n";
    } while ($v == ($maxval+1));
    push @vals, $min+$v;
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
