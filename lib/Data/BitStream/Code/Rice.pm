package Data::BitStream::Code::Rice;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::Rice::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Rice::VERSION = '0.02';
}

use Mouse::Role;
requires qw(read write put_unary get_unary);

sub put_rice {
  my $self = shift;
  my $sub;
  my $k = shift;
  if (ref $k eq 'CODE') {   # Check for sub as first parameter
    $sub = $k;
    $k = shift;
  }

  die "k must be >= 0" unless $k >= 0;
  return( (defined $sub) ? $sub->($self, @_) : $self->put_unary(@_) ) if $k==0;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    my $q = $val >> $k;
    my $r = $val - ($q << $k);
    (defined $sub)  ?  $sub->($self, $q)  :  $self->put_unary($q);
    $self->write($k, $r);
  }
  1;
}
sub get_rice {
  my $self = shift;
  my $sub;
  my $k = shift;
  if (ref $k eq 'CODE') {   # Check for sub as first parameter
    $sub = $k;
    $k = shift;
  }

  die "k must be >= 0" unless $k >= 0;
  return( (defined $sub) ? $sub->($self, @_) : $self->get_unary(@_) ) if $k==0;

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $q = (defined $sub)  ?  $sub->($self)  :  $self->get_unary();
    last unless defined $q;
    push @vals, ($q << $k)  |  $self->read($k);
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
