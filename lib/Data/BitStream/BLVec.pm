package Data::BitStream::BLVec;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::BLVec::AUTHORITY = 'cpan:DANAJ';
  $Data::BitStream::BLVec::VERSION   = '0.01';
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
     'Data::BitStream::Code::Baer',
     'Data::BitStream::Code::ARice',
     'Data::BitStream::Code::StartStop';

use Data::BitStream::BitList;

has '_vec' => (is => 'rw',
               isa => 'Data::BitStream::BitList',
               default => sub { return Data::BitStream::BitList->new(0) });

# Force our pos and len sets to also set the BitList
has '+pos' => (trigger => sub { shift->_vec->setpos(shift) });
has '+len' => (trigger => sub { shift->_vec->setlen(shift) });

after 'erase' => sub {
  my $self = shift;
  $self->_vec->erase;
  1;
};
after 'write_close' => sub {
  my $self = shift;
  $self->_vec->trim;
  1;
};

sub read {
  my $self = shift;
  die "get while writing" if $self->writing;
  my $bits = shift;
  die "Invalid bits" unless defined $bits && $bits > 0 && $bits <= $self->maxbits;
  my $peek = (defined $_[0]) && ($_[0] eq 'readahead');

  my $vref = $self->_vec;

  return $vref->readahead($bits)  if $peek;

  my $val = $vref->read($bits);
  $self->_setpos( $vref->pos );
  $val;
}
sub write {
  my $self = shift;
  die "put while not writing" unless $self->writing;
  my $bits = shift;
  die "Bits must be > 0" unless $bits > 0;
  my $val  = shift;
  die "Undefined value" unless defined $val;

  my $vref = $self->_vec;

  $vref->write($bits, $val);

  $self->_setlen( $vref->len );
  1;
}

# This is a bit ugly, but my other alternatives:
#
#   1) hand-write each sub.
#      Error prone, and lots of duplication.
#
#   2) make a _generic_put and then:
#      sub put_unary { _generic_put( sub { shift->put_unary(shift) }, @_) }
#      Very nice, but adds time for every value
#
#   3) _generic_put with a for loop inside the sub argument.
#      Solves performance, but now unwieldy and not generic.
#
#   3) Use *{$fn} = sub { ... }; instead of eval.
#      100ns slower!
#

sub _generate_generic_put {
  my $param = shift;
  my $fn   = shift;
  my $blfn = shift || $fn;

  my $st = "sub $fn {\n " .
'  my $self = shift;
   die "put while not writing" unless $self->writing;
   __GETPARAM__
   my $vref = $self->_vec;
   $vref->__CALLFUNC__;
   $self->_setlen( $vref->len );
   1;
 }';

  if ($param ne '') {
    $st =~ s/__GETPARAM__/my \$p = shift;\n   $param;/;
    $st =~ s/__CALLFUNC__/$blfn(\$p, \@_)/;
  } else {
    $st =~ s/__GETPARAM__//;
    $st =~ s/__CALLFUNC__/$blfn(\@_)/;
  }

  no strict 'refs';
  undef *{$fn};
  eval $st;
  warn $@ if $@;
}
sub _generate_generic_put_old {
  my $param = shift;
  my $fn   = shift;
  my $blfn = shift || $fn;

  my $st = "sub $fn {\n " .
'  my $self = shift;
   die "put while not writing" unless $self->writing;
   __GETPARAM__
   my $vref = $self->_vec;
   foreach my $val (@_) {
     $vref->__CALLFUNC__;
   }
   $self->_setlen( $vref->len );
   1;
 }';

  if ($param ne '') {
    $st =~ s/__GETPARAM__/my \$p = shift;\n   $param;/;
    $st =~ s/__CALLFUNC__/$blfn(\$p, \$val)/;
  } else {
    $st =~ s/__GETPARAM__//;
    $st =~ s/__CALLFUNC__/$blfn(\$val)/;
  }

  no strict 'refs';
  undef *{$fn};
  eval $st;
  warn $@ if $@;
}

sub _generate_generic_get {
  my $param = shift;
  my $fn   = shift;
  my $blfn = shift || $fn;

  my $st = "sub $fn {\n " .
'  my $self = shift;
  die "get while writing" if $self->writing;
  __GETPARAM__
  my $vref = $self->_vec;

  if (wantarray) {
    my @vals = $vref->__CALLFUNC__;
    $self->_setpos( $vref->pos );
    return @vals;
  } else {
    my $val = $vref->__CALLFUNC__;
    $self->_setpos( $vref->pos );
    return $val;
  }
}';
  if ($param ne '') {
    $st =~ s/__GETPARAM__/my \$p = shift;\n   $param;/g;
    $st =~ s/__CALLFUNC__/$blfn(\$p, \@_)/g;
  } else {
    $st =~ s/__GETPARAM__//g;
    $st =~ s/__CALLFUNC__/$blfn(\@_)/g;
  }

  no strict 'refs';
  undef *{$fn};
  eval $st;
  warn $@ if $@;
}

sub _generate_generic_getput {
  my $param = shift;
  my $code = shift;
  my $blcode = shift || $code;
  _generate_generic_put($param, 'put_'.$code, 'put_'.$blcode );
  _generate_generic_get($param, 'get_'.$code, 'get_'.$blcode );
}


_generate_generic_getput('', 'unary');
_generate_generic_getput('', 'unary1');
_generate_generic_getput('', 'gamma');
_generate_generic_getput('', 'delta');
_generate_generic_getput('', 'omega');
_generate_generic_getput('', 'fib');
_generate_generic_getput('', 'levenstein');
_generate_generic_getput('', 'evenrodeh');
#_generate_generic_get('', 'get_levenstein');

_generate_generic_getput(
   'die "invalid parameters" unless $p > 0',
   'gammagolomb', 'gamma_golomb');
_generate_generic_getput(
   'die "invalid parameters" unless $p >= 0 && $p <= $self->maxbits',
   'expgolomb', 'gamma_rice');

_generate_generic_getput(
   'die "invalid parameters" unless $p >= -32 && $p <= 32',
   'baer');

_generate_generic_getput(
   'die "invalid parameters" unless $p > 0 && $p <= $self->maxbits',
   'binword');

_generate_generic_put(
   'if (ref $p eq "CODE") {
      return Data::BitStream::Code::ARice::put_arice($self, $p, @_);
    }
    die "k must be >= 0" unless $p >= 0;',
   'put_arice', 'put_adaptive_gamma_rice');
_generate_generic_get(
   'if (ref $p eq "CODE") {
      return Data::BitStream::Code::ARice::get_arice($self, $p, @_);
    }
    die "k must be >= 0" unless $p >= 0;',
   'get_arice', 'get_adaptive_gamma_rice');
_generate_generic_put(
   'if (ref $p eq "CODE") {
      return Data::BitStream::Code::Rice::put_rice($self, $p, @_);
    }
    die "k must be >= 0" unless $p >= 0;',
   'put_rice');
_generate_generic_get(
   'if (ref $p eq "CODE") {
      return Data::BitStream::Code::Rice::get_rice($self, $p, @_);
    }
    die "k must be >= 0" unless $p >= 0;',
   'get_rice');
_generate_generic_put(
   'if (ref $p eq "CODE") {
      return Data::BitStream::Code::Golomb::put_golomb($self, $p, @_);
    }
    die "m must be >= 1" unless $p >= 1;',
   'put_golomb');
_generate_generic_get(
   'if (ref $p eq "CODE") {
      return Data::BitStream::Code::Golomb::get_golomb($self, $p, @_);
    }
    die "m must be >= 1" unless $p >= 1;',
   'get_golomb');

sub put_string {
  my $self = shift;
  die "put while reading" unless $self->writing;

  my $vref = $self->_vec;

  foreach my $str (@_) {
    next unless defined $str;
    die "invalid string" if $str =~ tr/01//c;
    $vref->put_string($str);
  }
  $self->_setlen( $vref->len );
  #die "put_string len mismatch" unless $self->len == $vref->len();
  1;
}

sub read_string {
  my $self = shift;
  my $bits = shift;
  die "Invalid bits" unless defined $bits && $bits >= 0;
  die "Short read" unless $bits <= ($self->len - $self->pos);
  my $vref = $self->_vec;
  $vref->read_string($bits);
}

sub to_raw {
  my $self = shift;
  $self->write_close;
  my $vref = $self->_vec;
  return $vref->to_raw;
}

sub from_raw {
  my $self = $_[0];
  # data comes in 2nd argument
  my $bits = $_[2] || 8*length($_[1]);

  $self->write_open;
  my $vref = $self->_vec;
  $vref->from_raw($_[1], $bits);

  $self->_setlen( $bits );
  $self->rewind_for_read;
}

# default everything else

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
