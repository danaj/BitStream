#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use lib qw(t/lib BitStream/t/lib Data/BitStream/t/lib);
use BitStreamTest;

my @implementations = impl_list;
my @encodings       = encoding_list;

plan tests => scalar @encodings;

foreach my $encoding (@encodings) {
  subtest "$encoding" => sub { test_encoding($encoding); };
}
done_testing();


sub test_encoding {
  my $encoding = shift;

  plan tests => scalar @implementations;

  foreach my $type (@implementations) {
    my $success = 1;
    my $maxbits = 16;
    my $maxpat  = 0xFFFF;
    if (is_universal($encoding)) {
      my $stream = new_stream($type);
      $maxbits = $stream->maxbits;
      $maxpat = ~0;
    }

    my @data;
    # Note we're not encoding 2^max-1.  The range test does that.
    foreach my $bits (1 .. $maxbits-1) {
      my $maxval = $maxpat >> ($maxbits - $bits);
      # maxvals separated by binary '10001' and '0'
      push @data, $maxval, 17, $maxval, 0, $maxval;
    }

    my $stream = stream_encode_array($type, $encoding, @data);
    BAIL_OUT("No stream of type $type") unless defined $stream;
    my @v = stream_decode_array($encoding, $stream);
    foreach my $i (0 .. $#data) {
      $success = 0 if $v[$i] != $data[$i];
    }
    $success = 0 if $stream->pos != $stream->len;
    ok($success, "$encoding put/get bit patterns using $type");
  }
}
