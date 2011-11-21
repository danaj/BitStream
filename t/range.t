#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use List::Util qw(shuffle);
use lib qw(t/lib);
use BitStreamTest;

my $maxval = ~0;
my @maxdata = (0, 1, 2, 33, 65, 129,
               ($maxval >> 1) - 2,
               ($maxval >> 1) - 1,
               ($maxval >> 1),
               ($maxval >> 1) + 1,
               ($maxval >> 1) + 2,
               $maxval-2,
               $maxval-1,
               $maxval,
              );

push @maxdata, @maxdata;
@maxdata = shuffle @maxdata;


my @implementations = impl_list;
my @encodings = grep { is_universal($_) } encoding_list;
# Remove codings that cannot encode ~0
#@encodings = grep { $_ !~ /^(Omega|BVZeta)/i } @encodings;

plan tests => scalar @implementations * scalar @encodings;

foreach my $type (@implementations) {
  foreach my $encoding (@encodings) {

    my $stream = stream_encode_array($type, $encoding, @maxdata);
    my @v = stream_decode_array($encoding, $stream);
    is_deeply( \@v, \@maxdata, "$type: $encoding range patterns");

  }
}
