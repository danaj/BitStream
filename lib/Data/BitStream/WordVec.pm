package Data::BitStream::WordVec;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Vec::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Vec::VERSION = '0.01';
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

has '_vec' => (is => 'rw', default => '');

# Access the raw vector.
sub _vecref {
  my $self = shift;
 \$self->{_vec};
}
after 'erase' => sub {
  my $self = shift;
  $self->_vec('');
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

  my $wpos = $pos >> 5;       # / 32
  my $bpos = $pos & 0x1F;     # % 32
  my $rvec = $self->_vecref;
  my $val = 0;

  if ($bits == 1) {  # optimize
    $val = (vec($$rvec, $wpos, 32) >> (31-$bpos)) & 1;
  } else {
    my $bits_left = $bits;
    while ($bits_left > 0) {
      my $epos = (($bpos+$bits_left) > 32)  ?  32  :  $bpos+$bits_left;
      my $bits_to_read = $epos - $bpos;  # between 0 and 32
      my $v = vec($$rvec, $wpos, 32);
      $v >>= (32-$epos);
      $v &= (0xFFFFFFFF >> (32-$bits_to_read));

      $val = ($val << $bits_to_read) | $v;

      $wpos++;
      $bits_left -= $bits_to_read;
      $bpos = 0;
    }
  }

  $self->_setpos( $pos + $bits ) unless $peek;
  $val;
}
sub write {
  my $self = shift;
  die "put while reading" unless $self->writing;
  my $bits = shift;
  die "Invalid bits" unless defined $bits && $bits > 0 && $bits <= $self->maxbits;
  my $val  = shift;
  die "Undefined value" unless defined $val;

  my $len  = $self->len;
  my $new_len = $len + $bits;

  if ($val == 0) {                # optimize writing 0
    $self->_setlen( $new_len );
    return 1;
  }

  if ($val == 1) { $len += $bits-1; $bits = 1; } # optimize

  my $wpos = $len >> 5;       # / 32
  my $bpos = $len & 0x1F;     # % 32
  my $rvec = $self->_vecref;

  while ($bits > 0) {
    my $epos = (($bpos+$bits) > 32)  ?  32  :  $bpos+$bits;
    my $bits_to_write = $epos - $bpos;  # between 0 and 32

    # get rid of parts of val to the right that we aren't writing yet
    my $val_to_write = $val >> ($bits - $bits_to_write);
    # get rid of parts of val to the left
    $val_to_write &= 0xFFFFFFFF >> (32-$bits_to_write);

    vec($$rvec, $wpos, 32)  |=  ($val_to_write << (32-$epos));

    $wpos++;
    $bits -= $bits_to_write;
    $bpos = 0;
  }

  $self->_setlen( $new_len );
  1;
}

sub put_unary {
  my $self = shift;
  die "put while reading" unless $self->writing;

  my $len  = $self->len;
  my $rvec = $self->_vecref;

  foreach my $val (@_) {
    # We're writing $val 0's, so just skip them
    $len += $val;
    my $wpos = $len >> 5;      # / 32
    my $bpos = $len & 0x1F;    # % 32

    # Write a 1 in the correct position
    vec($$rvec, $wpos, 32) |= (1 << ((32-$bpos) - 1));
    $len++;
  }

  $self->_setlen( $len );
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
  my $rvec = $self->_vecref;

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $onepos = $pos;
    my $wpos = $pos >> 5;      # / 32
    my $bpos = $pos & 0x1F;    # % 32
    my $v = 0;
    # Get the current word, shifted left so current position is leftmost.
    if ($bpos > 0) {
      $v = (vec($$rvec, $wpos++, 32) & (0xFFFFFFFF >> $bpos)) << $bpos;
    }
    # If this word is 0, advance words until we find one that is non-zero.
    if ($v == 0) {
      $onepos += (32-$bpos) if $bpos > 0;
      my $startwpos = $wpos;
      my $lastwpos = ($len+31) >> 5;

      # Something using this method could be very fast:
      #   my $maxwords = $lastwpos - $wpos + 1;
      #   my $slen = ($maxwords > 128) ?  128*4  :  $maxwords*4;
      #   substr($$rvec,$wpos*4,$slen) =~ /((?:\x00{4})+)/;
      # but it looks like I'm hitting endian issues.
      # Using tr/\000/\000/ to count leading zeros is the same.

      # Quickly skip forward through very long runs of zeros
      $wpos += 8 while ( (($wpos+6) < $lastwpos) && (substr($$rvec,$wpos*4,32) eq "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00") );
      #$wpos += 4 while ( (($wpos+2) < $lastwpos) && (substr($$rvec,$wpos*4,16) eq "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00") );

      while ( ($wpos <= $lastwpos) && ($v == 0) ) {
        $v = vec($$rvec, $wpos++, 32);
      }
      $onepos += 32*($wpos-1 - $startwpos);
    }
    die "get_unary read off end of vector" if $onepos >= $len;
    die if $v == 0;
    # This word is non-zero.  Find the leftmost set bit.
    if (($v & 0xFFFF0000) == 0) { $onepos += 16; $v <<= 16; }
    if (($v & 0xFF000000) == 0) { $onepos +=  8; $v <<=  8; }
    if (($v & 0xF0000000) == 0) { $onepos +=  4; $v <<=  4; }
    if (($v & 0xC0000000) == 0) { $onepos +=  2; $v <<=  2; }
    if (($v & 0x80000000) == 0) { $onepos +=  1; $v <<=  1; }
    push @vals, $onepos - $pos;
    $pos = $onepos+1;
  }
  $self->_setpos( $pos );
  wantarray ? @vals : $vals[-1];
}

# Using default get_string, put_string

sub to_string {
  my $self = shift;
  $self->write_close;
  my $len = $self->len;
  my $rvec = $self->_vecref;
  my $str = unpack("B$len", $$rvec);
  # unpack sometimes drops 0 bits at the end, so we need to check and add them.
  my $strlen = length($str);
  die if $strlen > $len;
  if ($strlen < $len) {
    $str .= "0" x ($len - $strlen);
  }
  $str;
}
sub from_string {
  my $self = shift;
  my $str  = shift;
  my $bits = shift || length($str);
  $self->write_open;

  my $rvec = $self->_vecref;
  $$rvec = pack("B*", $str);
  $self->_setlen($bits);

  $self->rewind_for_read;
}

# Using default to_raw, from_raw

sub to_store {
  my $self = shift;
  $self->write_close;
  $self->_vec;
}
sub from_store {
  my $self = shift;
  my $vec  = shift;
  my $bits = shift || length($vec);
  $self->write_open;
  $self->_vec( $vec );
  $self->_setlen( $bits );
  $self->rewind_for_read;
}

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
