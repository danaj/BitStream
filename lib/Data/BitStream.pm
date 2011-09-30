package Data::BitStream;
# I have tested with 5.8.9 and later.
# I was unable to install Mouse on 5.8.0.
use strict;
use warnings;

our $VERSION = '0.03';

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Data::BitStream ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);


# Pick one implementation as the default.
#
# String is usually fastest, but more memory than the others (1 byte per bit).
#
# WordVec is space and time efficient, hence is used as the default.
#
# Vec is deprecated.
#
# BitVec (using Bit::Vector) can be faster or slower than WordVec depending
# on which methods are used.  It is possible that a different implementation
# would result in much faster overall speed.

use Data::BitStream::WordVec;
use Mouse;
extends 'Data::BitStream::WordVec';
no Mouse;

1;
__END__


# ABSTRACT: A bit stream class including integer coding methods

=pod

=head1 NAME

Data::BitStream - A bit stream class including integer coding methods

=head1 SYNOPSIS

  use Data::BitStream;
  my $stream = Data::BitStream->new;
  $stream->put_gamma($_) for (1 .. 20);
  $stream->rewind_for_read;
  my @values = $stream->get_gamma(-1);

See the examples for more uses.

=head1 DESCRIPTION

A Mouse/Moose class providing read/write access to bit streams.  This includes
many integer coding methods as well as straightforward ways to implement new
codes.

Bit streams are often used in data compression and in embedded products where
memory is at a premium.  While this Perl implementation may not be appropriate
for many of these applications (speed and Perl), it can be very useful for
prototyping and experimenting with different codes.  A future implementation
using XS for internals may resolve some performance concerns.


=head1 EXAMPLES

=head2 Display bit patterns for some codes

  use Data::BitStream;
  sub string_of { my $stream = Data::BitStream->new;
                  $_[0]->($stream);
                  return $stream->to_string; }
  my @codes = qw(Gamma Delta Omega Fib);
  printf "%5s  " . (" %-11s" x scalar @codes) . "\n", 'N', @codes;
  foreach my $n (0 .. 20) {
    printf "%5d  ", $n;
    printf " %-11s", string_of(sub{shift->put_gamma($n)});
    printf " %-11s", string_of(sub{shift->put_delta($n)});
    printf " %-11s", string_of(sub{shift->put_omega($n)});
    printf " %-11s", string_of(sub{shift->put_fib($n)});
    print "\n";
  }


=head2 A simple predictor/encoder compression snippit

  use Data::BitStream;
  my $stream = Data::BitStream->new;
  # Loop over the data: characters, pixels, table entries, etc.
  foreach my $v (@values) {
    # predict the current value using your subroutine.  This routine
    # will use one or more previous values to estimate the current one.
    my $p = predict($v);
    # determine the signed difference.
    my $diff = $v - $p;
    # Turn this into an absolute difference suitable for coding.
    my $error = ($diff < 0)  ?  -2*$diff  :  2*$diff-1;
    # Encode this using gamma encoding (or whichever works best for you).
    $stream->put_gamma($error);
  }
  # Nicely packed up compressed data.
  my $compressed_data = $stream->to_raw;

This is a classic prediction-coding style compression method, used in many
applications.  Most lossless image compressors use this method, though often
with some extra steps further reduce the error term.  JPEG-LS, for example,
uses a very simple predictor, and puts its effort into relatively complex
bias estimations and adaptive determination of the parameter for Rice coding.

=head2 Convert Elias Delta encoded strings into Fibonacci encoded strings

  #/usr/bin/perl
  use Data::BitStream;
  my $d = Data::BitStream->new;
  my $f = Data::BitStream->new;
  while (<>) {
    chomp;
    $d->from_string($_);
    $f->erase_for_write;
    $f->put_fib( $d->get_delta(-1) );
    print scalar $f->to_string, "\n";
  }

=head2 Using a custom encoding method

  use Data::BitStream;
  use Data::BitStream::Code::Baer;
  use Data::BitStream::Code::BoldiVigna;

  my $stream = Data::BitStream->new;
  Data::BitStream::Code::Baer->meta->apply($stream);
  Data::BitStream::Code::BoldiVigna->meta->apply($stream);

  $stream->put_baer(-1, 14);      # put 14 as a Baer c-1 code
  $stream->put_boldivigna(2, 7);  # put 7 as a Zeta(2) code

  $stream->rewind_for_read;
  my $v1 = $stream->get_baer(-1);
  my $v2 = $stream->get_boldivigna(2);

Not all codes are included by default, including the power-law codes of
Michael Baer, the Zeta codes of Boldi and Vigna, and Escape codes.  These,
and any other codes write or acquire, can be incorporated using
L<Moose::Meta::Role> as shown above.

=head1 METHODS

=head2 CLASS METHODS

=over 4

=item B< maxbits >

Returns the number of bits in a word, which is the largest allowed size of
the C<bits> argument to C<read> and C<write>.  This will be either 32 or 64.

=back

=head2 OBJECT METHODS (I<reading>)

These methods are only value while the stream is in reading state.

=over 4

=item B< rewind >

Moves the position to the stream beginning.

=item B< exhausted >

Returns true is the stream is at the end.  Rarely used.

=item B< read($bits [, 'readahead']) >

Reads C<$bits> from the stream and returns the value.
C<$bits> must be between C<1> and C<maxbits>.

The position is advanced unless the second argument is the string 'readahead'.

=item B< skip($bits) >

Advances the position C<$bits> bits.  Used in conjunction with C<readahead>.

=item B< read_string($bits) >

Reads C<$bits> bits from the stream and returns them as a binary string, such
as '0011011'.

=back

=head2 OBJECT METHODS (I<writing>)

These methods are only value while the stream is in writing state.

=over 4

=item B< write($bits, $value) >

Writes C<$value> to the stream using C<$bits> bits.  
C<$bits> must be between C<1> and C<maxbits>.

The length is increased by C<$bits> bits.

Regardless of the contents of C<$value>, exactly C<$bits> bits will be used.
If C<$value> has more non-zero bits than C<$bits>, the lower bits are written.
In other words, C<$value> will be masked before writing.

=item B< put_string(@strings) >

Takes one or more binary strings, such as '1001101', '001100', etc. and
writes them to the stream.  The number of bits used for each value is equal
to the string length.

=item B< put_stream($source_stream) >

Writes the contents of C<$source_stream> to the stream.  This is a helper
method that might be more efficient than doing it in one of the many other
possible ways.  The default implementation uses:

  $self->put_string( $source_stream->to_string );

=back

=head2 OBJECT METHODS (I<conversion>)

These methods may be called at any time, and will adjust the state of the
stream.

=over 4

=item B< to_string >

Returns the stream as a binary string, e.g. '00110101'.

=item B< to_raw >

Returns the stream as packed big-endian data.  This form is portable to
any other implementation on any architecture.

=item B< to_store >

Returns the stream as some scalar holding the data in some implementation
specific way.  This may be portable or not, but it can always be read by
the same implementation.  It might be more efficient than the raw format.

=item B< from_string($string) >

The stream will be set to the binary string C<$string>.

=item B< from_raw($packed [, $bits]) >

The stream is set to the packed big-endian vector C<$packed> which has
C<$bits> bits of data.  If C<$bits> is not present, then C<length($packed)>
will be used as the byte-length.  It is recommended that you include C<$bits>.

=item B< from_store($blob [, $bits]) >

Similar to C<from_raw>, but using the value returned by C<to_store>.

=back

=head2 OBJECT METHODS (I<other>)

=over 4

=item B< pos >

A read-only non-negative integer indicating the current position in a read
stream.  It is advanced by C<read>, C<get>, and C<skip> methods, as well
as changed by C<to>, C<from>, C<rewind>, and C<erase> methods.

=item B< len >

A read-only non-negative integer indicating the current length of the stream
in bits.  It is advanced by C<write> and C<put> methods, as well as changed
by C<from> and C<erase> methods.

=item B< writing >

A read-only boolean indicating whether the stream is open for writing or
reading.  Methods for read such as
C<read>, C<get>, C<skip>, C<rewind>, C<skip>, and C<exhausted>
are not allowed while writing.  Methods for write such as
C<write> and C<put>
are not allowed while reading.  

The C<write_open> and C<erase_for_write> methods will set writing to true.
The C<write_close> and C<rewind_for_read> methods will set writing to false.

The read/write distinction allows implementations more freedom in internal
caching of data.  For instance, they can gather writes into blocks.  It also
can be helpful in catching mistakes such as reading from a target stream.

=item B< erase >

Erases all the data, while the writing state is left unchanged.  The position
and length will both be 0 after this is finished.

=item B< write_open >

Changes the state to writing with no other API-visible changes.

=item B< write_close >

Changes the state to reading, and the position is set to the end of the
stream.  No other API-visible changes happen.

=item B< erase_for_write >

A helper function that performs C<erase> followed by C<write_open>.

=item B< rewind_for_read >

A helper function that performs C<write_close> followed by C<rewind>.

=back

=head2 OBJECT METHODS (I<coding>)

All coding methods are biased to 0.  This means values from 0 to 2^maxbits-1
(for universal codes) may be encoded, even if the original code as published
starts with 1.

All C<get_> methods take an optional count as the last argument.
If C<$count> is C<1> or not supplied, a single value will be read.
If C<$count> is positive, that many values will be read.
If C<$count> is negative, values are read until the end of the stream.

C<get_> methods called in list context this return a list of all values read.
Called in scalar context they return the last value read.

C<put_> methods take one or more values as input after any optional
parameters and write them to the stream.  All values must be non-negative
integers that do not exceed the maximum encodable value (~0 for universal
codes, parameter-specific for others).

=over 4

=item B< get_unary([$count]) >

=item B< put_unary(@values) >

Reads/writes one or more values from the stream in C<0000...1> unary coding.
Unary coding is only appropriate for relatively small numbers, as it uses
C<$value + 1> bits per value.

=item B< get_unary1([$count]) >

=item B< put_unary1(@values) >

Reads/writes one or more values from the stream in C<1111...0> unary coding.

=item B< get_binword($bits, [$count]) >

=item B< put_binword($bits, @values) >

Reads/writes one or more values from the stream as fixed-length binary
numbers, each using C<$bits> bits.

=item B< get_gamma([$count]) >

=item B< put_gamma(@values) >

Reads/writes one or more values from the stream in Elias Gamma coding.

=item B< get_delta([$count]) >

=item B< put_delta(@values) >

Reads/writes one or more values from the stream in Elias Delta coding.

=item B< get_omega([$count]) >

=item B< put_omega(@values) >

Reads/writes one or more values from the stream in Elias Omega coding.

=item B< get_levenstein([$count]) >

=item B< put_levenstein(@values) >

Reads/writes one or more values from the stream in Levenstein coding
(sometimes called Levenshtein or Левенште́йн coding).

=item B< get_evenrodeh([$count]) >

=item B< put_evenrodeh(@values) >

Reads/writes one or more values from the stream in Even-Rodeh coding.

=item B< get_fib([$count]) >

=item B< put_fib(@values) >

Reads/writes one or more values from the stream in Fibonacci coding.
Specifically, the order C<m=2> C1 codes of Fraenkel and Klein.

=item B< get_fib_c2([$count]) >

=item B< put_fib_c2(@values) >

Reads/writes one or more values from the stream in Fibonacci C2 coding.
Specifically, the order C<m=2> C2 codes of Fraenkel and Klein.  Note that
these codes are not prefix-free, hence they will not mix well with other
codes in the same stream.

=item B< get_golomb($m [, $count]) >

=item B< put_golomb($m, @values) >

Reads/writes one or more values from the stream in Golomb coding.

=item B< get_golomb(sub { ... }, $m [, $count]) >

=item B< put_golomb(sub { ... }, $m, @values) >

Reads/writes one or more values from the stream in Golomb coding using the
supplied subroutine instead of unary coding, which can make them work with
large outliers.  For example to use Fibonacci coding for the base:

  $stream->put_golomb( sub {shift->put_fib(@_)}, $m, $value);

  $value = $stream->put_golomb( sub {shift->get_fib(@_)}, $m);

=item B< get_rice($k [, $count]) >

=item B< put_rice($k, @values) >

Reads/writes one or more values from the stream in Rice coding, which is
the time efficient case where C<m = 2^k>.

=item B< get_rice(sub { ... }, $k [, $count]) >

=item B< put_rice(sub { ... }, $k, @values) >

Reads/writes one or more values from the stream in Rice coding using the
supplied subroutine instead of unary coding, which can make them work with
large outliers.  For example to use Omega coding for the base:

  $stream->put_rice( sub {shift->put_omega(@_)}, $k, $value);

  $value = $stream->put_rice( sub {shift->get_omega(@_)}, $k);

=item B< get_gammagolomb($m [, $count]) >

=item B< put_gammagolomb($m, @values) >

Reads/writes one or more values from the stream in Golomb coding using
Elias Gamma codes for the base.  This is a convenience since they are common.

=item B< get_expgolomb($k [, $count]) >

=item B< put_expgolomb($k, @values) >

Reads/writes one or more values from the stream in Rice coding using
Elias Gamma codes for the base.  This is a convenience since they are common.

=item B< get_startstop(\@m [, $count]) >

=item B< put_startstop(\@m, @values) >

Reads/writes one or more values using Start/Stop codes.  The parameter is an
array reference which can be an anonymous array, for example:

  $stream->put_startstop( [0,3,2,0], @array );
  my @array2 = $stream->get_startstop( [0,3,2,0], -1);

=item B< get_startstepstop(\@m [, $count]) >

=item B< put_startstepstop(\@m, @values) >

Reads/writes one or more values using Start-Step-Stop codes.  The parameter
is an array reference which can be an anonymous array, for example:

  $stream->put_startstepstop( [3,2,9], @array );
  my @array3 = $stream->get_startstepstop( [3,2,9], -1);

=back

=head1 SEE ALSO

=over 4

=item L<Data::BitStream::Base>

=item L<Data::BitStream::WordVec>

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

=head1 AUTHORS

Dana Jacobsen <dana@acm.org>

=head1 COPYRIGHT

Copyright 2011 by Dana Jacobsen <dana@acm.org>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
