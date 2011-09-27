#!/usr/bin/perl
use strict;
use warnings;

$| = 1;  # fast pipes
use BitStream::String;
use BitStream::WordVec;
use BitStream::Vec;
use BitStream::BitVec;
my $stream = BitStream::String->new();

my $ntest = 1_000;
my $nrand = 4_000;

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

# convert to/from decimal and BE binary, should work with 32- and 64-bit.
sub dec_to_bin {
  my $v =  ($_[1] > 0xFFFFFFFF)  ?  pack("Q", $_[1])  :  pack("L", $_[1]);
  scalar reverse unpack("b$_[0]", $v);
}
sub bin_to_dec { no warnings 'portable'; oct '0b' . substr($_[1], 0, $_[0]); }
sub base_of { my $d = shift; my $base = 0; $base++ while ($d >>= 1); $base; }




# Unary:  0 based
sub encode_unary {
  ('0' x (shift)) . '1';
}
sub decode_unary {
  index($_[0], '1', 0);
}

# Gamma:  1 based
sub encode_gamma {
  my $d = shift;
  die "Value must be between 1 and ~0" unless $d >= 1 and $d <= ~0;
  my $base = base_of($d);
  my $str = encode_unary($base);
  if ($base > 0) {
    $str .= dec_to_bin($base, $d);
  }
  $str;
}
sub decode_gamma {
  my $str = shift;
  my $base = decode_unary($str);
  my $val = 1 << $base;
  if ($base > 0) {
    $val |= bin_to_dec($base, substr($str, $base+1));
  }
  $val;
}

# Delta:  1 based
sub encode_delta {
  my $d = shift;
  die "Value must be between 1 and ~0" unless $d >= 1 and $d <= ~0;
  my $base = base_of($d);
  my $str = encode_gamma($base+1);
  if ($base > 0) {
    $str .= dec_to_bin($base, $d);
  }
  $str;
}
sub decode_delta {
  my $str = shift;
  my $base = decode_gamma($str) - 1;
  my $val = 1 << $base;
  if ($base > 0) {
    # We have to figure out how far we need to look
    my $shift = length(encode_gamma($base+1));
    $val |= bin_to_dec($base, substr($str, $shift));
  }
  $val;
}

# Omega:  1 based
sub encode_omega {
  my $d = shift;
  die "Value must be between 1 and ~0" unless $d >= 1 and $d <= ~0;

  my $str = '0';
  while ($d > 1) {
    my $base = base_of($d);
    $str = dec_to_bin($base+1, $d) . $str;
    $d = $base;
  }
  $str;
}

sub decode_omega {
  my $str = shift;
  my $val = 1;
  while (substr($str,0,1) eq '1') {
    my $bits = $val+1;
    die "off end of string" unless length($str) >= $bits;
    $val = bin_to_dec($bits, $str);
    substr($str,0,$bits) = '';
  }
  $val;
}

# Fibonacci:  1 based
my @fibs;
sub _calc_fibs {
  @fibs = ();
  my ($v2, $v1) = (0, 1);
  while ($v1 <= ~0) {
    ($v2, $v1) = ($v1, $v2+$v1);
    push(@fibs, $v1);
  }
}
sub encode_fib {
  my $d = shift;
  die "Value must be between 1 and ~0" unless $d >= 1 and $d <= ~0;
  _calc_fibs unless defined $fibs[0];
  # Find the largest F(s) bigger than $n
  my $s =  ($d < $fibs[30])  ?  0  :  ($d < $fibs[60])  ?  31  :  61;
  $s++ while ($d >= $fibs[$s]);
  my $r = '1';
  while ($s-- > 0) {
    if ($d >= $fibs[$s]) {
      $d -= $fibs[$s];
      $r .= "1";
    } else {
      $r .= "0";
    }
  }
  scalar reverse $r;
}
sub decode_fib {
  my $str = shift;
  die "Invalid Fibonacci code" unless $str =~ /^[01]*11$/;
  my $val = 0;
  foreach my $b (0 .. length($str)-2) {
    $val += $fibs[$b]  if substr($str, $b, 1) eq '1';
  }
  $val;
}
