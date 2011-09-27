#!/usr/bin/perl
use strict;
use warnings;
use lib qw(../lib ../t/lib);
use Data::BitStream;

eval "require 'integercoding.pl'";

$| = 1;  # fast pipes
my $stream = Data::BitStream->new();

my $ntest = 10_000;
my $nrand = 40_000;

if (1) {
print "Unary...";
  foreach my $n (0 .. $ntest) { test_unary($n); }
print "...SUCCESS\n";
print "Gamma...";
  foreach my $n (1 .. $ntest) { test_gamma($n); }
print "...SUCCESS\n";
print "Delta...";
  foreach my $n (1 .. $ntest) { test_delta($n); }
print "...SUCCESS\n";
print "Omega...";
  foreach my $n (1 .. $ntest) { test_omega($n); }
print "...SUCCESS\n";
print "Fib.....";
  foreach my $n (1 .. $ntest) { test_fib($n); }
print "...SUCCESS\n";
}

srand(101);
print "Random gamma/delta/omega/fib..";
foreach my $i (1 .. $nrand) {
  print "." if $i % int($nrand/30) == 0;
  my $n = int(rand(10_000_000_000));
  test_gamma($n);
  test_delta($n);
  test_omega($n);
  test_fib($n);
}
print "SUCCESS\n";


sub test_unary {
  my $n = shift;
  my $s1 = encode_unary($n);
  my $v1 = decode_unary($s1);
  $stream->erase_for_write();
  $stream->put_unary($n);
  my $s2 = $stream->to_string();
  $stream->from_string($s2);
  my $v2 = $stream->get_unary();
  die "encode mismatch for $n" unless $s1 eq $s2;
  die "decode mismatch for $n" unless $v1 eq $v2 and $v1 eq $n;
  1;
}
sub test_gamma {
  my $n = shift;
  my $s1 = encode_gamma($n);
  my $v1 = decode_gamma($s1);
  $stream->erase_for_write();
  $stream->put_gamma($n-1);
  my $s2 = $stream->to_string();
  $stream->from_string($s2);
  my $v2 = $stream->get_gamma() + 1;
  die "encode mismatch for $n" unless $s1 eq $s2;
  die "decode mismatch for $n" unless $v1 eq $v2 and $v1 eq $n;
  1;
}
sub test_delta {
  my $n = shift;
  my $s1 = encode_delta($n);
  my $v1 = decode_delta($s1);
  $stream->erase_for_write();
  $stream->put_delta($n-1);
  my $s2 = $stream->to_string();
  $stream->from_string($s2);
  my $v2 = $stream->get_delta() + 1;
  die "encode mismatch for $n" unless $s1 eq $s2;
  die "decode mismatch for $n" unless $v1 eq $v2 and $v1 eq $n;
  1;
}
sub test_omega {
  my $n = shift;
  my $s1 = encode_omega($n);
  my $v1 = decode_omega($s1);
  $stream->erase_for_write();
  $stream->put_omega($n-1);
  my $s2 = $stream->to_string();
  $stream->from_string($s2);
  my $v2 = $stream->get_omega() + 1;
  die "encode mismatch for $n" unless $s1 eq $s2;
  die "decode mismatch for $n" unless $v1 eq $v2 and $v1 eq $n;
  1;
}
sub test_fib {
  my $n = shift;
  my $s1 = encode_fib($n);
  my $v1 = decode_fib($s1);
  $stream->erase_for_write();
  $stream->put_fib($n-1);
  my $s2 = $stream->to_string();
  $stream->from_string($s2);
  my $v2 = $stream->get_fib() + 1;
  die "encode mismatch for $n" unless $s1 eq $s2;
  die "decode mismatch for $n" unless $v1 eq $v2 and $v1 eq $n;
  1;
}
