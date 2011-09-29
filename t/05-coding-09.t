#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use lib qw(t/lib);
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
    my $nvals = 500;
    my @data;
    srand(52);
    for (1 .. $nvals) {
      push @data, int(rand(1025));
    }
    my $stream = stream_encode_array($type, $encoding, @data);
    BAIL_OUT("No stream of type $type") unless defined $stream;
    my @v = stream_decode_array($encoding, $stream);
    foreach my $i (0 .. $#data) {
      $success = 0 if $v[$i] != $data[$i];
    }
    ok($success, "$encoding store $nvals random values using $type");
  }
}
