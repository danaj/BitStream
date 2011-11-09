package Data::BitStream::MinimalVec;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::MinimalVec::AUTHORITY = 'cpan:DANAJ';
  $Data::BitStream::MinimalVec::VERSION   = '0.01';
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
     'Data::BitStream::Code::BoldiVigna',
     'Data::BitStream::Code::ARice',
     'Data::BitStream::Code::StartStop';

has '_vec' => (is => 'rw', default => '');

sub _vecref { \shift->{_vec} }
after 'erase' => sub { shift->_vec(''); 1; };

sub read {
  my $self = shift;
  die "read while writing" if $self->writing;
  my $bits = shift;
  die "invalid bits: $bits" unless defined $bits && $bits > 0 && $bits <= $self->maxbits;
  my $peek = (defined $_[0]) && ($_[0] eq 'readahead');

  my $pos = $self->pos;
  my $len = $self->len;
  return if $pos >= $len;

  my $val = 0;
  my $rvec = $self->_vecref;
  foreach my $bit (0 .. $bits-1) {
    $val = ($val << 1) | vec($$rvec, $pos+$bit, 1);
  }
  $self->_setpos( $pos + $bits ) unless $peek;
  $val;
}
sub write {
  my $self = shift;
  die "write while reading" unless $self->writing;
  my $bits = shift;
  die "invalid bits: $bits" unless defined $bits && $bits > 0;
  my $val  = shift;
  die "undefined value" unless defined $val;

  my $len  = $self->len;
  my $rvec = $self->_vecref;

  if ($val == 0) {
    # nothing
  } elsif ($val == 1) {
    vec($$rvec, $len + $bits - 1, 1) = 1;
  } else {
    die "invalid bits: $bits" if $bits > $self->maxbits;

    my $wpos = $len + $bits-1;
    foreach my $bit (0 .. $bits-1) {
      vec($$rvec, $wpos - $bit, 1) = 1  if  (($val >> $bit) & 1);
    }
  }

  $self->_setlen( $len + $bits);
  1;
}

# default everything else

__PACKAGE__->meta->make_immutable;
no Mouse;
1;

# ABSTRACT: A minimal implementation of Data::BitStream

=pod

=head1 NAME

Data::BitStream::MinimalVec - A minimal implementation of Data::BitStream

=head1 SYNOPSIS

  use Data::BitStream::MinimalVec;
  my $stream = Data::BitStream::MinimalVec->new;
  $stream->put_gamma($_) for (1 .. 20);
  $stream->rewind_for_read;
  my @values = $stream->get_gamma(-1);

=head1 DESCRIPTION

An implementation of L<Data::BitStream>.  See the documentation for that
module for many more examples, and L<Data::BitStream::Base> for the API.
This document only describes the unique features of this implementation,
which is of limited value to people purely using L<Data::BitStream>.

This implementation uses a Perl C<vec> to store the data, and shows basically
the minimal work required to get an implementation working.  Everything else
is provided by the base class.  It is slow, and L<Data::BitStream::WordVec>
is recommended for real work.

=head2 DATA

=over 4

=item B< _vec >

A private scalar holding the data as a vector.

=back

=head2 CLASS METHODS

=over 4

=item B< _vecref >

Retrieves a reference to the private vector.

=item I<after> B< erase >

Sets the private vector to the empty string C<''>.

=item B< read >

=item B< write >

These methods have custom implementations.

=back

=head2 ROLES

The following roles are included.

=over 4

=item L<Data::BitStream::Code::Base>

=item L<Data::BitStream::Code::Gamma>

=item L<Data::BitStream::Code::Delta>

=item L<Data::BitStream::Code::Omega>

=item L<Data::BitStream::Code::Levenstein>

=item L<Data::BitStream::Code::EvenRodeh>

=item L<Data::BitStream::Code::Fibonacci>

=item L<Data::BitStream::Code::Golomb>

=item L<Data::BitStream::Code::Rice>

=item L<Data::BitStream::Code::GammaGolomb>

=item L<Data::BitStream::Code::ExponentialGolomb>

=item L<Data::BitStream::Code::StartStop>

=back

=head1 SEE ALSO

=over 4

=item L<Data::BitStream>

=item L<Data::BitStream::Base>

=item L<Data::BitStream::WordVec>

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2011 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
