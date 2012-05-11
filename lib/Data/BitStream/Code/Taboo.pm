package Data::BitStream::Code::Taboo;
use strict;
use warnings;
BEGIN {
  $Data::BitStream::Code::Taboo::AUTHORITY = 'cpan:DANAJ';
  $Data::BitStream::Code::Taboo::VERSION = '0.01';
}

our $CODEINFO = { package   => __PACKAGE__,
                  name      => 'BlockTaboo',
                  universal => 1,
                  params    => 1,
                  encodesub => sub {shift->put_blocktaboo(@_)},
                  decodesub => sub {shift->get_blocktaboo(@_)}, };

use Mouse::Role;
requires qw(read write);

sub put_blocktaboo {
  my $self = shift;
  $self->error_stream_mode('write') unless $self->writing;
  my $bits = shift;
  $self->error_code('param', 'bits must be in range 1-16') unless $bits >= 1 && $bits <= 16;

  return $self->put_unary(@_) if $bits == 1;
  my $taboo = 0;
  my $base = 2**$bits - 1;      # The base of the digits we're writing

  foreach my $val (@_) {
    $self->error_code('zeroval') unless defined $val and $val >= 0;

    if ($val == 0) { $self->write($bits, $taboo);  next; }

    #my $lbase = ($val <= $base)  ?  0  :  int( log($val) / log($base) );
    my $lbase = int( log($val + 1 - (($val+2)/$base)) / log($base) + 1) - 1;
    my $v = $val - 2**$bits**$lbase;
    #my $v = $val-1;
print "v: $v  base $base  lbase $lbase\n";
    #$v -= $base ** $lbase if $lbase > 0;
    foreach my $i (reverse 0 .. $lbase) {
      my $factor = $base ** $i;
      my $digit = int($v / $factor);
print "v $v  i $i  factor $factor  encode digit: $digit\n";
      $v -= $digit * $factor;
      # TODO: avoid an arbitrary taboo
      $self->write($bits, $digit+1);
    }
    $self->write($bits, $taboo);
  }
  1;
}

sub get_blocktaboo {
  my $self = shift;
  $self->error_stream_mode('read') if $self->writing;
  my $bits = shift;
  $self->error_code('param', 'bits must be in range 1-16') unless $bits >= 1 && $bits <= 16;

  return $self->get_unary(@_) if $bits == 1;
  my $taboo = 0;
  my $base = 2**$bits - 1;      # The base of the digits we're writing

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my @vals;
  $self->code_pos_start('Block Taboo');
  while ($count-- > 0) {
    $self->code_pos_set;
    my $tval = $self->read($bits);
    last unless defined $tval;

    if ($tval == $taboo) { push @vals, 0;  next; }

    my $val = 0;
    do {
      $val = $base * $val + $tval + 1;
      $tval = $self->read($bits);
      $self->error_off_stream unless defined $tval;
    } while ($tval != $taboo);
    push @vals, $val+1;
  }
  $self->code_pos_end;
  wantarray ? @vals : $vals[-1];
}

no Mouse::Role;
1;

# ABSTRACT: A Role implementing Taboo codes

=pod

=head1 NAME

Data::BitStream::Code::Taboo - A Role implementing Taboo codes

=head1 VERSION

version 0.01

=head1 DESCRIPTION

A role written for L<Data::BitStream> that provides get and set methods for
Taboo codes.  The role applies to a stream object.

Taboo codes are described in Steven Pigeon's 2001 PhD Thesis as well as his
paper "Taboo Codes: New Classes of Universal Codes."

The block methods implement a slight modification of the taboo codes.  An
example with C<n=2>:

      value        code          binary         bits
          0           t                    11    2
          1          0t                  0011    4
          2          1t                  0111    4
          3          2t                  1011    4
          4         00t                000011    6
  ..     11         22c                101011    6
         12        000c              00000011    8
  ..     64       2100c            1001000011   10
  ..  10000  111201100c  01010110000101000011   20

These codes are a more efficient version of comma codes.

TODO: Correct code for 64 and 10000 above.

=head1 METHODS

=head2 Provided Object Methods

=over 4

=item B< put_blocktaboo($bits, $value) >

=item B< put_blocktaboo($bits, @values) >

Insert one or more values as block taboo codes using C<$bits> bits.  Returns 1.

=item B< get_blocktaboo($bits) >

=item B< get_blocktaboo($bits, $count) >

Decode one or more block taboo codes from the stream.  If count is omitted,
one value will be read.  If count is negative, values will be read until
the end of the stream is reached.  In scalar context it returns the last
code read; in array context it returns an array of all codes read.

=back

=head2 Parameters

The parameter C<bits> must be an integer between 1 and 16.  This indicates
the number of bits used per chunk.

If C<bits> is 1, then unary coding is used.

=head2 Required Methods

=over 4

=item B< read >

=item B< write >

These methods are required for the role.

=back

=head1 SEE ALSO

=over 4

=item Steven Pigeon, "Taboo Codes: New Classes of Universal Codes", 2001.

=back

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2012 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
