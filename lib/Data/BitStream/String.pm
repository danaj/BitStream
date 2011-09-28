package Data::BitStream::String;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::String::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::String::VERSION = '0.01';
}

use Mouse;

with 'Data::BitStream::Base',
     #'Data::BitStream::Code::Gamma',  # implemented here
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

has '_str' => (is => 'rw', default => '');

# Evil, reference to underlying string
sub _strref {
  my $self = shift;
 \$self->{_str};
}
after 'erase' => sub {
  my $self = shift;
  $self->_str('');
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

  # What about reading past the end in this read?
  my $rstr = $self->_strref;
  my $str = substr($$rstr, $pos, $bits);
  { # This is for readahead.  We should use a write-close method instead.
    my $strlen = length($str);
    $str .= "0" x ($bits-$strlen)  if $strlen < $bits;
  }
  my $val;
  # We could do something like:
  #    $val = unpack("N", pack("B32", substr("0" x 32 . $str, -32)));
  # and combine for more than 32-bit values, but this works better.
  {
    no warnings 'portable';
    $val = oct "0b$str";
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

  my $rstr = $self->_strref;

  # The following is fastest on a LE machine:
  #
  #   my $packed_val = ($bits <= 32)  ?  pack("L", $val)  :  pack("Q", $val);
  #   $$rstr .= scalar reverse unpack("b$bits", $packed_val);
  #
  # With 5.9.2 and later, this will work:
  #
  #   $$rstr .= substr(unpack("B64", pack("Q>", $v)), -$bits);
  #
  # This seems to be the most portable:
  if ($bits > 32) {
    $$rstr .=   substr(unpack("B32", pack("N", $val>>32)), -($bits-32))
              . unpack("B32", pack("N", $val));
  } else {
    $$rstr .= substr(unpack("B32", pack("N", $val)), -$bits);
  }

  $self->_setlen( $self->len + $bits);
  1;
}

sub put_unary {
  my $self = shift;
  die "put while reading" unless $self->writing;

  my $rstr = $self->_strref;
  my $len = $self->len;

  foreach my $val (@_) {
    $$rstr .= '0' x ($val) . '1';
    $len += $val+1;
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
  my $rstr = $self->_strref;

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $onepos = index( $$rstr, '1', $pos );
    die "read off end of stream" if $onepos == -1;
    my $val = $onepos - $pos;
    $pos = $onepos + 1;
    push @vals, $val;
  }
  $self->_setpos( $pos );
  wantarray ? @vals : $vals[-1];
}

sub put_unary1 {
  my $self = shift;
  die "put while reading" unless $self->writing;

  my $rstr = $self->_strref;
  my $len = $self->len;

  foreach my $val (@_) {
    $$rstr .= '1' x ($val) . '0';
    $len += $val+1;
  }

  $self->_setlen( $len );
  1;
}
sub get_unary1 {
  my $self = shift;
  die "get while writing" if $self->writing;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my $pos = $self->pos;
  my $len = $self->len;
  my $rstr = $self->_strref;

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $onepos = index( $$rstr, '0', $pos );
    die "read off end of stream" if $onepos == -1;
    my $val = $onepos - $pos;
    $pos = $onepos + 1;
    push @vals, $val;
  }
  $self->_setpos( $pos );
  wantarray ? @vals : $vals[-1];
}

sub put_gamma {
  my $self = shift;
  die "put while reading" unless $self->writing;

  my $rstr = $self->_strref;
  my $len = $self->len;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    my $vstr;
    if    ($val == 0)  { $vstr = '1'; }
    elsif ($val == 1)  { $vstr = '010'; }
    elsif ($val == 2)  { $vstr = '011'; }
    elsif ($val == ~0) { $vstr = '0' x $self->maxbits . '1'; }
    else {
      my $base = 0;
      { my $v = $val+1; $base++ while ($v >>= 1); }
      $vstr = '0' x $base . '1';
      #my $packed_val = ($base <= 32)  ?  pack("L",$val+1)  :  pack("Q",$val+1);
      #$vstr .= scalar reverse unpack("b$base", $packed_val);
      if ($base > 32) {
        $vstr .=   substr(unpack("B32", pack("N", ($val+1)>>32)), -($base-32))
                 . unpack("B32", pack("N", $val+1));
      } else {
        $vstr .= substr(unpack("B32", pack("N", $val+1)), -$base);
      }
    }
    $$rstr .= $vstr;
    $len += length($vstr);
  }

  $self->_setlen( $len );
  1;
}

sub get_gamma {
  my $self = shift;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my $pos = $self->pos;
  my $len = $self->len;
  my $rstr = $self->_strref;

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $onepos = index( $$rstr, '1', $pos );
    die "read off end of stream" if $onepos == -1;
    my $base = $onepos - $pos;
    $pos = $onepos + 1;
    if    ($base == 0) {  push @vals, 0; }
    elsif ($base == $self->maxbits) { push @vals, ~0; }
    else  {
      my $vstr = substr($$rstr, $pos, $base);
      $pos += $base;
      my $rval;
      { no warnings 'portable';  $rval = oct "0b$vstr"; }
      push @vals, ((1 << $base) | $rval)-1;
    }
  }
  $self->_setpos( $pos );
  wantarray ? @vals : $vals[-1];
}

# Using default get_string, put_string

sub to_string {
  my $self = shift;
  $self->write_close;
  $self->_str;
}
sub from_string {
  my $self = shift;
  my $str  = shift;
  my $bits = shift || length($str);
  $self->write_open;
  $self->_str( $str );
  $self->_setlen( $bits );
  $self->rewind_for_read;
}

# Using default to_raw, from_raw
# Using default to_store, from_store

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
