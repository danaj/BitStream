package Data::BitStream::Code::GammaGolomb;
BEGIN {
  $Data::BitStream::Code::GammaGolomb::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::GammaGolomb::VERSION = '0.02';
}

use Mouse::Role;

requires 'put_golomb', 'put_gamma', 'get_golomb', 'get_gamma';

sub put_gammagolomb {
  my $self = shift;
  $self->put_golomb( sub { shift->put_gamma(@_); }, @_ );
}
sub get_gammagolomb {
  my $self = shift;
  $self->get_golomb( sub { shift->get_gamma(@_); }, @_ );
}
no Mouse;
1;
