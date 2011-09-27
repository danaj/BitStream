package Data::BitStream::Code::Rice;
BEGIN {
  $Data::BitStream::Code::Rice::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::Rice::VERSION = '0.01';
}

use Mouse::Role;

requires 'read', 'write', 'put_unary', 'get_unary';

sub put_rice {
  my $self = shift;
  my $k = shift;
  die "k must be >= 1" unless $k >= 1;

  foreach my $val (@_) {
    die "Value must be >= 0" unless $val >= 0;
    $self->put_unary($val >> $k);
    $self->write($k, $val);
  }
  1;
}
sub get_rice {
  my $self = shift;
  my $k = shift;
  die "k must be >= 1" unless $k >= 1;
  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  while ($count-- > 0) {
    my $q = $self->get_unary();
    last unless defined $q;
    push @vals, ($q << $k)  |  $self->read($k);
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
