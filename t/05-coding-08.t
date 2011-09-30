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

  plan tests => 2 * scalar @implementations;

  foreach my $type (@implementations) {
    my $success = 1;
    my @data = (0 .. 257);
    push @data, reverse @data;
    my $stream = stream_encode_array($type, $encoding, @data);
    BAIL_OUT("No stream of type $type") unless defined $stream;
    my @v = stream_decode_array($encoding, $stream);
    cmp_ok(scalar @v, '==', scalar @data, "$type: $encoding size");
    foreach my $i (0 .. $#data) {
      $success = 0 if $v[$i] != $data[$i];
    }
    ok($success, "$encoding store ascending/descending array using $type");
  }
}
