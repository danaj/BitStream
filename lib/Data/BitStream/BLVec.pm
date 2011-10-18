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

  my $pos = $self->pos;
  my $len = $self->len;
  return if $pos >= $len;

  my $vref = $self->_vec;
  die "read len mismatch" unless $len == $vref->getlen();
  $vref->setpos($pos);
  my $val = $vref->vread($bits);
  if ($peek) {
    $vref->setpos($pos);
  } else {
    $self->_setpos( $pos + $bits );
  }
  die "pos mismatch with bits $bits val $val $pos/$len" unless $self->pos == $vref->getpos();
  $val;
}
sub write {
  my $self = shift;
  die "put while not writing" unless $self->writing;
  my $bits = shift;
  die "Bits must be > 0" unless $bits > 0;
  my $val  = shift;
  die "Undefined value" unless defined $val;

  my $len  = $self->len;
  my $vref = $self->_vec;
  $vref->setlen($len);

  $vref->vwrite($bits, $val);

  $self->_setlen($len + $bits);
  die "len mismatch" unless $self->len == $vref->getlen();
  1;
}

sub put_unary {
  my $self = shift;
  die "put while not writing" unless $self->writing;

  my $len  = $self->len;
  my $vref = $self->_vec;

  die "put_unary len mismatch 1" unless $self->len == $vref->getlen();
  foreach my $val (@_) {
    #$self->write($val+1, 1);
    $vref->put_unary($val);
  }
  $self->_setlen( $vref->getlen );
  die "put_unary len mismatch 2" unless $self->len == $vref->getlen();
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
  $vref->setpos($pos);

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $v = $vref->get_unary;
    push @vals, $v;
    $pos += $v+1;
  }
  $self->_setpos( $pos );
  die "get_unary pos mismatch" unless $self->pos == $vref->getpos;
  wantarray ? @vals : $vals[-1];
}

sub put_gamma {
  my $self = shift;
  die "put while not writing" unless $self->writing;

  my $len  = $self->len;
  my $vref = $self->_vec;

  foreach my $val (@_) {
    $vref->put_gamma($val);
  }
  $self->_setlen( $vref->getlen );
  die "put_gamma len mismatch" unless $self->len == $vref->getlen();
  1;
}

sub get_gamma {
  my $self = shift;
  die "get while writing" if $self->writing;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my $pos = $self->pos;
  my $len = $self->len;
  my $vref = $self->_vec;
  $vref->setpos($pos);

  my @vals;
  while ($count-- > 0) {
    last if $pos >= $len;
    my $v = $vref->get_gamma;
    push @vals, $v;
    $pos = $vref->getpos;
  }
  $self->_setpos( $pos );
  die "get_unary pos mismatch" unless $self->pos == $vref->getpos;
  wantarray ? @vals : $vals[-1];
}

sub put_string {
  my $self = shift;
  die "put while reading" unless $self->writing;

  my $len = $self->len;
  my $vref = $self->_vec;

  foreach my $str (@_) {
    next unless defined $str;
    die "invalid string" if $str =~ tr/01//c;
    $vref->put_string($str);
  }
  $self->_setlen( $vref->getlen );
  die "put_string len mismatch" unless $self->len == $vref->getlen();
  1;
}


# default everything else

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
