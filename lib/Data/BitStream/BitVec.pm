package Data::BitStream::BitVec;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::BitVec::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::BitVec::VERSION = '0.01';
}

use Mouse;

with 'Data::BitStream::Base',
     'Data::BitStream::Code::Gamma',
     'Data::BitStream::Code::Delta',
     'Data::BitStream::Code::Omega',
     'Data::BitStream::Code::Levenstein',
     'Data::BitStream::Code::EvenRodeh',
     'Data::BitStream::Code::Fibonacci',
     'Data::BitStream::Code::Golomb',
     'Data::BitStream::Code::Rice',
     'Data::BitStream::Code::GammaGolomb',
     'Data::BitStream::Code::ExponentialGolomb',
     'Data::BitStream::Code::StartStop';

use Bit::Vector;
use 5.009_002;   # Using pack("Q<", $v) for big endian machines

has '_vec' => (is => 'rw',
               isa => 'Bit::Vector',
               default => sub { return Bit::Vector->new(0) });

after 'erase' => sub {
  my $self = shift;
  $self->_vec->Resize(0);
  1;
};
after 'write_close' => sub {
  my $self = shift;
  $self->_vec->Resize($self->len);
  1;
};

sub read {
  my $self = shift;
  die "get while writing" if $self->writing;
  my $bits = shift;
  die "Invalid bits" unless defined $bits && $bits > 0 && $bits <= $self->maxbits;
  my $peek = (defined $_[0]) && ($_[0] eq 'readahead');

  my $pos = $self->pos;
  my $len = $self->len;
  return if $pos >= $len;
  my $vref = $self->_vec;

  my $val;
  if ($bits == 1) {
    $val = $vref->bit_test($pos);
  } else {
    # Simple but slow code:
    #   $val = 0;
    #   foreach my $bit (0 .. $bits-1) {
    #     last if $pos+$bit >= $len;
    #     $val |= (1 << ($bits-$bit-1))  if $vref->bit_test($pos + $bit);
    #   }
    #
    # Read a chunk.  The returned value has the bits in LSB order.
    my $c = $vref->Chunk_Read($bits, $pos);
    my $pval = ($bits > 32) ? pack("Q<", $c) : pack("V", $c);
    { no warnings 'portable';  $val = oct("0b" . unpack("b$bits", $pval)); }
  }

  $self->_setpos( $pos + $bits ) unless $peek;
  $val;
}
sub write {
  my $self = shift;
  my $bits = shift;
  my $val  = shift;
  die "Bits must be > 0" unless $bits > 0;
  die "put while not writing" unless $self->writing;
  my $len  = $self->len;
  my $vref = $self->_vec;

  #$self->_vec->Resize( $len + $bits );
  # Bit::Vector will spend a LOT of time expanding its vector.  It's >REALLY<
  # slow.  It will exponentially dominate the time taken to write.  Hence
  # I will aggressively expand it.
  {
    my $vsize = $vref->Size();
    if (($len+$bits) > $vsize) {
      $vsize = int( ($len+$bits+2048) * 1.15 );
      $vref->Resize($vsize);
    }
  }

  if ($val == 0) {
    # Nothing
  } elsif ($val == 1) {
    $vref->Bit_On( $len + $bits - 1 );
  } else {
    # Simple method:
    #  my $wpos = $len + $bits-1;
    #  foreach my $bit (0 .. $bits-1) {
    #    $vref->Bit_On( $wpos - $bit )  if  (($val >> $bit) & 1);
    #  }
    # Alternate: reverse the bits of val and use efficient Chunk_Store
    my $pval = ($bits > 32) ? pack("Q<", $val) : pack("V", $val);
    { no warnings 'portable';  $val = oct("0b" . unpack("b$bits", $pval)); }
    $vref->Chunk_Store($bits, $len, $val);
  }

  $self->_setlen( $len + $bits);
  1;
}

sub put_unary {
  my $self = shift;

  my $len  = $self->len;
  my $vref = $self->_vec;
  my $vsize = $vref->Size();

  foreach my $val (@_) {
    my $bits = $val+1;
    if (($len+$bits) > $vsize) {
      $vsize = int( ($len+$bits+2048) * 1.15 );
      $vref->Resize($vsize);
    }
    $vref->Bit_On($len + $val);
    $len += $bits;
  }
  $self->_setlen($len);
  1;
}

sub get_unary {
  my $self = shift;
  die "get while writing" if $self->writing;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my $pos = $self->pos;
  my $len = $self->len;
  my $vref = $self->_vec;

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;

    #my $onepos = $pos;
    #$onepos += 32 while (    (($onepos+31) < $len)
    #                      && ($self->_vec->Chunk_Read(32, $onepos) == 0) );
    #$onepos +=  8 while (    (($onepos+7) < $len)
    #                      && ($self->_vec->Chunk_Read(8, $onepos) == 0) );
    #while ($onepos < $len) {
    #  last if $self->_vec->bit_test($onepos);
    #  $onepos++;
    #}
    #die "get_unary read off end of vector" if $onepos >= $len;

    # Interval_Scan is very, very fast.  In theory it could go wandering off
    # down the vector if we have a huge sequence of 1's after this unary value.
    my ($onepos, undef) = $vref->Interval_Scan_inc($pos);
    die "get_unary read off end of vector" unless defined $onepos;

    push @vals, $onepos - $pos;
    $pos = $onepos + 1;
  }
  $self->_setpos( $pos );
  wantarray ? @vals : $vals[-1];
}

# Using default get_string, put_string

# It'd be nice to use to_Bin and new_Bin since they're super fast.  But...
# they return the result in little endian.  Hence non-portable and won't
# match other implementations.

sub to_string2 {
  my $self = shift;
  $self->write_close;

  my $len = $self->len;
  my $vref = $self->_vec;
  my $str = '';
  foreach my $bit (0 .. $len-1) {
    $str .= $vref->bit_test($bit);
  }
  $str;
}
sub from_string2 {
  my $self = shift;
  my $str  = shift;
  my $bits = shift || length($str);
  $self->write_open;
  my $vref = $self->_vec;
  $vref->Resize($bits);
  $vref->Empty();
  foreach my $bit (0 .. $bits-1) {
    $vref->Bit_On($bit) if substr($str, $bit, 1) eq '1';
  }
  #$self->_vec(  Bit::Vector->new_Bin($bits, $str) );
  $self->_setlen( $bits );
  $self->rewind_for_read;
}

# Using default to_raw, from_raw
# Using default to_store, from_store

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
