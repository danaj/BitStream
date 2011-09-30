#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use lib qw(t/lib);
use BitStreamTest;

my @implementations = impl_list;

plan tests => scalar @implementations;

foreach my $type (@implementations) {

  my $encoding = 'gamma';

  {
    my $success = 1;
    my $nvals = 500;
    my @data;
    srand(110);
    for (1 .. $nvals) {
      push @data, int(rand(515));
    }
    my $stream = stream_encode_array($type, $encoding, @data);
    die "no stream for $encoding" unless defined $stream;

    my $raw = $stream->to_raw;
    my $rawlen = length($raw);
    my $len = $stream->len;
    my $wordlen = 4 * int( ($len + 31) / 32);
    my $bytelen = int( ($len + 7) / 8);

    ok( ($rawlen >= $bytelen) && ($rawlen <= $wordlen), "$type: appropriate length of raw stream" );
  }
}
done_testing();
