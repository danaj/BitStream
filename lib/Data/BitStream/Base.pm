package Data::BitStream::Base;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Base::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Base::VERSION = '0.01';
}

use Mouse::Role;

# pos is ignored while writing
has 'pos'  => (is => 'ro', isa => 'Int', writer => '_setpos', default => 0);
has 'len'  => (is => 'ro', isa => 'Int', writer => '_setlen', default => 0);
has 'writing' => (is => 'ro', isa => 'Bool', writer => '_set_write', default => 1);

# Useful to use for testing sometimes, but very time consuming
#after '_setpos' => sub {
#  my $self = shift;
#  my $pos = $self->pos;
#  my $len = $self->len;
#  die "position must be >= 0" if $pos < 0;
#  die "position must be <= length" if $pos > $len;
#  $pos;
#};

{
  use Config;
  my $mbits = 32;
  $mbits = 64 if defined $Config{'use64bitint'} && $Config{'use64bitint'} eq 'define';
  $mbits = 64 if defined $Config{'longsize'} && $Config{'longsize'} >= 8;

  sub maxbits { $mbits; }
}

sub rewind {
  my $self = shift;
  die "rewind while writing" if $self->writing;
  $self->_setpos(0);
  1;
}
sub skip {
  my $self = shift;
  die "skip while writing" if $self->writing;
  my $skip = shift;
  my $pos = $self->pos;
  my $len = $self->len;
  return 0 if ($pos + $skip) > $len;
  $self->_setpos($pos + $skip);
  1;
}
sub exhausted {
  my $self = shift;
  die "exhausted while writing" if $self->writing;
  $self->pos >= $self->len;
}
sub erase {
  my $self = shift;
  $self->_setlen(0);
  $self->_setpos(0);
  # Writing state is left unchanged
  # You want an after method to handle the data
}
sub write_open {
  my $self = shift;
  if (!$self->writing) {
    $self->_set_write(1);
    # pos is now ignored
  }
  1;
}
sub write_close {
  my $self = shift;
  if ($self->writing) {
    $self->_set_write(0);
    $self->_setpos($self->len);
  }
  1;
}

# combination functions
sub erase_for_write {
  my $self = shift;
  $self->erase;
  $self->write_open if !$self->writing;
}
sub rewind_for_read {
  my $self = shift;
  $self->write_close if $self->writing;
  $self->rewind;
}

sub readahead {
  my $self = shift;
  my $bits = shift;
  $self->read($bits, 'readahead');
}
sub read {                 # You need to implement this.
  die "Implement this.";
}
sub write {                # You need to implement this.
  die "Implement this.";
}
sub put_unary {
  my $self = shift;

  foreach my $val (@_) {
    warn "Trying to write large unary value ($val)" if $val > 10_000_000;
    $self->write(32, 0)  for (1 .. int($val/32));
    $self->write(($val%32)+1, 1);
  }
  1;
}
sub get_unary {            # You ought to override this.
  my $self = shift;
  die "get while writing" if $self->writing;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my $pos = $self->pos;
  my $len = $self->len;

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $val = 0;

    # Simple code:
    #
    #   my $maxval = $len - $pos - 1;  # Maximum unary value in remaining space
    #   $val++ while ( ($val <= $maxval) && ($self->read(1) == 0) );
    #   die "read off end of stream" if $pos >= $len;
    #
    # Faster code, looks at 32 bits at a time.  Still comparatively slow.

    my $word = $self->read(32, 'readahead');
    last unless defined $word;
    while ($word == 0) {
      die "read off end of stream" unless $self->skip(32);
      $val += 32;
      $word = $self->read(32, 'readahead');
    }
    while (($word & 0x80000000) == 0) {
      $val++;
      $word <<= 1;
    }
    $self->skip(($val % 32) + 1);

    push @vals, $val;
  }

  wantarray ? @vals : $vals[-1];
}

# Write unary as 1111.....0  instead of 0000.....1
sub put_unary1 {
  my $self = shift;

  foreach my $val (@_) {
    warn "Trying to write large unary value ($val)" if $val > 10_000_000;
    my $nwords = $val >> 5;
    my $nbits = $val % 32;
    $self->write(32, 0xFFFFFFFF)  for (1 .. $nwords);
    $self->write($nbits+1, 0xFFFFFFFE);
  }
  1;
}
sub get_unary1 {            # You ought to override this.
  my $self = shift;
  die "get while writing" if $self->writing;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my $pos = $self->pos;
  my $len = $self->len;

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $val = 0;

    # Simple code:
    #
    #   my $maxval = $len - $pos - 1;  # Maximum unary value in remaining space
    #   $val++ while ( ($val <= $maxval) && ($self->read(1) == 0) );
    #   die "read off end of stream" if $pos >= $len;
    #
    # Faster code, looks at 32 bits at a time.  Still comparatively slow.

    my $word = $self->read(32, 'readahead');
    last unless defined $word;
    while ($word == 0xFFFFFFFF) {
      die "read off end of stream" unless $self->skip(32);
      $val += 32;
      $word = $self->read(32, 'readahead');
    }
    while (($word & 0x80000000) != 0) {
      $val++;
      $word <<= 1;
    }
    $self->skip(($val % 32) + 1);

    push @vals, $val;
  }

  wantarray ? @vals : $vals[-1];
}

# binary values of given length
sub put_binword {
  my $self = shift;
  my $bits = shift;
  die "invalid parameters" if ($bits < 0) || ($bits > $self->maxbits);

  foreach my $val (@_) {
    $self->write($bits, $val);
  }
  1;
}
sub get_binword {
  my $self = shift;
  die "get while writing" if $self->writing;
  my $bits = shift;
  die "invalid parameters" if ($bits < 0) || ($bits > $self->maxbits);
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $val = $self->read($bits);
    last unless defined $val;
    push @vals, $val;
  }
  wantarray ? @vals : $vals[-1];
}


# Write one or more text binary strings (e.g. '10010')
sub put_string {
  my $self = shift;
  die "put while reading" unless $self->writing;

  foreach my $str (@_) {
    my $bits = length($str);
    my $spos = 0;
    while ($bits >= 32) {
      $self->write(32, oct('0b' . substr($str, $spos, 32)));
      $spos += 32;
      $bits -= 32;
    }
    if ($bits > 0) {
      $self->write($bits, oct('0b' . substr($str, $spos, $bits)));
    }
  }
  1;
}
# Get a text binary string.  Similar to read, but bits can be 0 - len.
sub read_string {
  my $self = shift;
  my $bits = shift;
  die "Invalid bits" unless defined $bits && $bits >= 0;
  die "Short read" unless $bits <= ($self->len - $self->pos);
  my $str = '';
  while ($bits >= 32) {
    $str .= unpack("B32", pack("N", $self->read(32)));
    $bits -= 32;
  }
  if ($bits > 0) {
    $str .= substr(unpack("B32", pack("N", $self->read($bits))), -$bits);
  }
  $str;
}

# Conversion to and from strings of 0's and 1's.  Note that the order is
# completely left to right based on what was written.

sub to_string {            # You should override this.
  my $self = shift;
  $self->rewind_for_read;
  $self->read_string($self->len);
}
sub from_string {          # You should override this.
  my $self = shift;
  #my $str  = shift;
  #my $bits = shift || length($str);
  $self->erase_for_write;
  $self->put_string($_[0]);
  $self->rewind_for_read;
}

# Conversion to and from binary.  Note that the order is completely left to
# right based on what was written.  This means it is an array of big-endian
# units.  This implementation uses 32-bit words as the units.

sub to_raw {               # You ought to override this.
  my $self = shift;
  $self->rewind_for_read;
  my $len = $self->len;
  my $pos = $self->pos;
  my $vec = '';
  while ( ($pos+31) < $len ) {
    $vec .= pack("N", $self->read(32));
    $pos += 32;
  }
  if ($pos < $len) {
    $vec .= pack("N", $self->read($len-$pos) << 32-($len-$pos));
  }
  $vec;
}
sub from_raw {             # You ought to override this.
  my $self = shift;
  my $vec  = shift;
  my $bits = shift || int((length($vec)+7)/8);
  $self->erase_for_write;
  my $vpos = 0;
  while ($bits >= 32) {
    $self->write(32, unpack("N", substr($vec, $vpos, 4)));
    $vpos += 4;
    $bits -= 32;
  }
  if ($bits > 0) {
    my $nbytes = int(($bits+7)/8);             # this many bytes left
    my $pvec = substr($vec, $vpos, $nbytes);   # extract the bytes
    vec($pvec,33,1) = 0;                       # zero fill the 32-bit word
    my $word = unpack("N", $pvec);             # unpack the filled word
    $word >>= (32-$bits);                      # shift data to lower bits
    $self->write($bits, $word);                # write data to stream
  }
  $self->rewind_for_read;
}

# Conversion to and from your internal data.  This can be in any form desired.
# This could be a little-endian array, or a byte stream, or a string, etc.
# The main point is that we can get a single chunk that can be saved off, and
# later can restore the stream.  This should be efficient.

sub to_store {             # You ought to implement this.
  my $self = shift;
  $self->to_raw(@_);
}
sub from_store {           # You ought to implement this.
  my $self = shift;
  $self->from_raw(@_);
}

# Helper class methods for other functions
sub _floorlog2 {
  my $d = shift;
  my $base = 0;
  $base++ while ($d >>= 1);
  $base;
}
sub _ceillog2 {
  my $d = shift;
  $d--;
  my $base = 1;
  $base++ while ($d >>= 1);
  $base;
}
sub _bin_to_dec {
  no warnings 'portable';
  oct '0b' . substr($_[1], 0, $_[0]);
}
sub _dec_to_bin {
  # The following is fastest on a LE machine:
  #
  #   my $v = ($_[0] > 32)  ?  pack("Q", $_[1])  :  pack("L", $_[1]);
  #   scalar reverse unpack("b$_[0]", $v);
  #
  # With 5.9.2 and later, this will work:
  #
  #   substr(unpack("B64", pack("Q>", $_[1])), -$_[0]);
  #
  # This seems to be the most portable:
  my $bits = shift;
  my $val = shift;
  if ($bits > 32) {
    return   substr(unpack("B32", pack("N", $val>>32)), -($bits-32))
           . unpack("B32", pack("N", $val));
  } else {
    return substr(unpack("B32", pack("N", $val)), -$bits);
  }
}

no Mouse;
1;
