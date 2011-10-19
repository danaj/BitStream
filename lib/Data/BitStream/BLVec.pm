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
  $self->_vec->resize(0);
  1;
};
after 'write_close' => sub {
  my $self = shift;
  $self->_vec->resize($self->len);
  1;
};

sub read {
  my $self = shift;
  die "get while writing" if $self->writing;
  my $bits = shift;
  die "Invalid bits" unless defined $bits && $bits > 0 && $bits <= $self->maxbits;
  my $peek = (defined $_[0]) && ($_[0] eq 'readahead');

  my $vref = $self->_vec;

  return $vref->vreadahead($bits)  if $peek;

  my $val = $vref->vread($bits);
  $self->_setpos( $vref->getpos );
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

  $vref->vwrite($bits, $val);

  $self->_setlen( $vref->getlen );
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
  my $fn   = shift;
  my $blfn = shift || $fn;

  no strict 'refs';
  undef *{$fn};
  eval "sub $fn {" .
'  my $self = shift;
   die "put while not writing" unless $self->writing;
   my $vref = $self->_vec;
   foreach my $val (@_) {
     $vref->' . $blfn . '($val);
   }
   $self->_setlen( $vref->getlen );
   1;
 }';
}

sub _generate_generic_get {
  my $fn   = shift;
  my $blfn = shift || $fn;

  no strict 'refs';
  undef *{$fn};
  eval "sub $fn {" .
'  my $self = shift;
  die "get while writing" if $self->writing;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my $vref = $self->_vec;

  my @vals;
  while ($count-- > 0) {
    my $v = $vref->' . $blfn . ';
    last unless defined $v;
    push @vals, $v;
  }
  $self->_setpos( $vref->getpos );
  wantarray ? @vals : $vals[-1];
}';
}

sub _generate_generic_getput {
  my $code = shift;
  _generate_generic_put( 'put_' . $code );
  _generate_generic_get( 'get_' . $code );
}


_generate_generic_getput('unary');
_generate_generic_getput('unary1');
_generate_generic_getput('gamma');
_generate_generic_getput('delta');
_generate_generic_getput('omega');
_generate_generic_getput('fib');


sub put_string {
  my $self = shift;
  die "put while reading" unless $self->writing;

  my $vref = $self->_vec;

  foreach my $str (@_) {
    next unless defined $str;
    die "invalid string" if $str =~ tr/01//c;
    $vref->put_string($str);
  }
  $self->_setlen( $vref->getlen );
  #die "put_string len mismatch" unless $self->len == $vref->getlen();
  1;
}


# default everything else

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
