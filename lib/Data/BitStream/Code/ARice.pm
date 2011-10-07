package Data::BitStream::Code::ARice;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::ARice::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::ARice::VERSION = '0.01';
}

use Mouse::Role;
requires qw(read write write_close put_unary get_unary);

sub _ceillog2_arice {
  my $d = $_[0] - 1;
  my $base = 1;
  $base++ while ($d >>= 1);
  $base;
}

sub _adjust_k {
  my ($k, $q) = @_;
  return $k-1  if $q == 0  &&  $k > 0;
  return $k+1  if $q >= 8  &&  $k < 60;
  $k;
}

#my @hist;
#my $nhist = 4;
#sub _adjust_k2 {
#  my ($k, $q) = @_;
#  push @hist, $q;
#  if ($#hist >= $nhist) {
#    shift @hist;
#  }
#  my $t = 0;
#  map { $t += $_ } @hist;
#  $t = int( ($t+$nhist-1) / scalar @hist + 0.5 );
#  my $nk = 0;
#  $nk = _ceillog2_arice($t) if $t > 0;
#  $nk = 60 if $nk > 60;
##print "k is $k, hist is @hist, t is $t, nk is $nk\n";
#  return $nk;
#}
#after 'write_close' => sub {
#  @hist = ();
#  1;
#};

sub put_arice {
  my $self = shift;
  my $sub;
  my $k = shift;
  if (ref $k eq 'CODE') {   # Check for sub as first parameter
    $sub = $k;
    $k = shift;
  }

  die "k must be >= 0" unless $k >= 0;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    my($q, $r);
    if ($k > 0) {
      $q = $val >> $k;
      $r = $val - ($q << $k);
      (defined $sub)  ?  $sub->($self, $q)  :  $self->put_gamma($q);
      $self->write($k, $r);
    } else {
      $q = $val;
      (defined $sub)  ?  $sub->($self, $q)  :  $self->put_gamma($q);
    }
    # adjust k
    $k = _adjust_k($k, $q);
  }
  $k;
}
sub get_arice {
  my $self = shift;
  my $sub;
  my $k = shift;
  if (ref $k eq 'CODE') {   # Check for sub as first parameter
    $sub = $k;
    $k = shift;
  }

  die "k must be >= 0" unless $k >= 0;
  #return( (defined $sub) ? $sub->($self, @_) : $self->get_unary(@_) ) if $k==0;

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $q = (defined $sub)  ?  $sub->($self)  :  $self->get_gamma();
    last unless defined $q;
    push @vals, ($k == 0)  ?  $q  :  (($q << $k) | $self->read($k));
    # adjust k
    $k = _adjust_k($k, $q);
  }
  wantarray ? @vals : $vals[-1];
  # how to return k?
}
no Mouse::Role;
1;
