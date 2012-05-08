package Data::BitStream::Code::ARice;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::ARice::AUTHORITY = 'cpan:DANAJ';
  $Data::BitStream::Code::ARice::VERSION   = '0.01';
}

our $CODEINFO = { package   => __PACKAGE__,
                  name      => 'ARice',
                  universal => 1,
                  params    => 1,
                  encodesub => sub {shift->put_arice(@_)},
                  decodesub => sub {shift->get_arice(@_)}, };

use Mouse::Role;
requires qw(read write write_close put_unary get_unary);

sub _ceillog2_arice {
  my $d = $_[0] - 1;
  my $base = 1;
  $base++ while ($d >>= 1);
  $base;
}

use constant QLOW  => 0;
use constant QHIGH => 7;

sub _adjust_k {
  my ($k, $q) = @_;
  return $k-1  if $q <= QLOW  &&  $k > 0;
  return $k+1  if $q >= QHIGH &&  $k < 60;
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
  my $sub = shift if ref $_[0] eq 'CODE';
  my $k = shift;
  $self->error_code('param', 'k must be >= 0') unless $k >= 0;

  # If small values are common (k often 0) then this will reduce the number
  # of method calls required, which makes us run a little faster.
  my @q_list;

  foreach my $val (@_) {
    $self->error_code('zeroval') unless defined $val and $val >= 0;
    if ($k == 0) {
      push @q_list, $val;
      $k++ if $val >= QHIGH;   # _adjust_k shortcut
    } else {
      my $q = $val >> $k;
      my $r = $val - ($q << $k);
      if (@q_list) {
        push @q_list, $q;
        (defined $sub)  ?  $sub->($self, @q_list)  :  $self->put_gamma(@q_list);
        @q_list = ();
      } else {
        (defined $sub)  ?  $sub->($self, $q)  :  $self->put_gamma($q);
      }
      $self->write($k, $r);
      $k = _adjust_k($k, $q);
    }
  }
  if (@q_list) {
    (defined $sub)  ?  $sub->($self, @q_list)  :  $self->put_gamma(@q_list);
  }
  $k;
}
sub get_arice {
  my $self = shift;
  my $sub = shift if ref $_[0] eq 'CODE';
  my $k = shift;
  $self->error_code('param', 'k must be >= 0') unless $k >= 0;

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  $self->code_pos_start('ARice');
  while ($count-- > 0) {
    $self->code_pos_set;
    # Optimization: if possible (k==0), read two values at once.
    my($q, $q1);
    if ( ($k == 0) && ($count > 0) ) {
      ($q1, $q) = (defined $sub)  ?  $sub->($self, 2)  :  $self->get_gamma(2);
      last unless defined $q1;
      push @vals, $q1;
      $k = _adjust_k($k, $q1);
      $count--;
      $self->code_pos_set;
    } else {
      $q = (defined $sub)  ?  $sub->($self)  :  $self->get_gamma();
    }
    last unless defined $q;
    if ($k == 0) {
      push @vals, $q;
    } else {
      my $remainder = $self->read($k);
      $self->error_off_stream unless defined $remainder;
      push @vals, (($q << $k) | $remainder);
    }
    $k = _adjust_k($k, $q);
  }
  $self->code_pos_end;
  wantarray ? @vals : $vals[-1];
  # how to return k?
}
no Mouse::Role;
1;
