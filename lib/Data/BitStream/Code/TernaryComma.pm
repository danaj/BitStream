package Data::BitStream::Code::TernaryComma;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::TernaryComma::AUTHORITY = 'cpan:DANAJ';
  $Data::BitStream::Code::TernaryComma::VERSION = '0.01';
}

our $CODEINFO = { package   => __PACKAGE__,
                  name      => 'TernaryComma',
                  universal => 1,
                  params    => 0,
                  encodesub => sub {shift->put_ternarycomma(@_)},
                  decodesub => sub {shift->get_ternarycomma(@_)}, };

use Mouse::Role;
requires qw(read write);

sub put_ternarycomma {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;

  foreach my $val (@_) {
    $self->error_code('zeroval') unless defined $val and $val >= 0;

    if ($val == 0) { $self->write(2, 3);  next; }  # c
    if ($val == 1) { $self->write(4, 3);  next; }  # 0c

    my $v = $val-1;
    my $lbase = int( log($v) / log(3) );
    # We should optimize writes (e.g. single 32-bit)
    foreach my $i (reverse 0 .. $lbase) {
      my $digit = int($v / (3**$i));
      $v -= $digit * (3**$i);
      $self->write(2, $digit);
    }
    $self->write(2, 3);
  }
  1;
}

sub get_ternarycomma {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  $self->code_pos_start('TernaryComma');
  while ($count-- > 0) {
    $self->code_pos_set;
    my $tval = $self->read(2);
    last unless defined $tval;

    if ($tval == 3) { push @vals, 0;  next; }

    my $val = 0;
    do {
      $val = 3 * $val + $tval;
      $tval = $self->read(2);
      $self->error_off_stream unless defined $tval;
    } while ($tval != 3);
    push @vals, $val+1;
  }
  $self->code_pos_end;
  wantarray ? @vals : $vals[-1];
}
no Mouse::Role;
1;

# ABSTRACT: A Role implementing Ternary Comma codes

=pod

=head1 NAME

Data::BitStream::Code::TernaryComma - A Role implementing Ternary Comma codes

=head1 VERSION

version 0.01

=head1 DESCRIPTION

A role written for L<Data::BitStream> that provides get and set methods for
Ternary Comma codes.  The role applies to a stream object.

=head1 METHODS

=head2 Provided Object Methods

=over 4

=item B< put_ternarycomma($value) >

=item B< put_ternarycomma(@values) >

Insert one or more values as Ternary Comma codes.  Returns 1.

=item B< get_ternarycomma() >

=item B< get_ternarycomma($count) >

Decode one or more Ternary Comma codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=back

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item Peter Fenwick, "Punctured Elias Codes for variable-length coding of the integers", Technical Report 137, Department of Computer Science, University of Auckland, December 1996.

=item Peter Fenwick,  “Ziv-Lempel encoding with multi-bit flags”, Proc. Data Compression Conference (IEEE DCC), Snowbird, Utah, pp 138–147, March 1993.

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2012 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
