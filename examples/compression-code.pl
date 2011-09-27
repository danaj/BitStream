#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
use Data::Dumper;
use List::Util qw(shuffle sum max);
use Time::HiRes qw(gettimeofday tv_interval);
use lib qw(../lib ../t/lib);
use Data::BitStream;
use BitStreamTest;
use POSIX;

# Time with small, big, and mixed numbers.

sub ceillog2 {
  my $v = shift;
  $v--;
  my $b = 1;
  $b++  while ($v >>= 1);
  $b;
}

#my @encodings = qw|unary gamma delta omega fib fibc2 gg(3) evenrodeh levenstein ss(0-2-7-99) deltagol(20) omegagol(20) fibgol(20) ergol(20) golomb(3) bvzeta(2) bvzeta(3) rice(2) rice(3) rice(4)|;
#my @encodings = qw|gamma delta gg(11) eg(3)|;
#my @encodings = qw|unary gamma delta omega fib|;
#my @encodings = qw|fib fibc2|;
#my @encodings = qw|unary|;
#my @encodings = qw|sss(2-3-20) ss(0-1-3-5-12)|;
my @encodings = qw|unary gamma omega levenstein ss(0-2-7) ss(0-1-2-6) ss(0-0-1-1-7) baer(-4)|;

# These files contain a lot of gamma encoded numbers generated from a
# multidimensional prediction algorithm.  They should be between 0 and 510,
# hence fit in 9 bits (generated from signed pixel differences).
my $file = '3d-gamma.txt';
#my $file = '4d-gamma.txt';
my @list;
{
  my $stream = Data::BitStream->new;
  open(my $fp, "<", $file) or die;
  while (<$fp>) {
    chomp;
    next if /#/;
    $stream->put_string($_);
  }
  close $fp;
  $stream->rewind_for_read;
  @list = $stream->get_gamma(-1);
}

print "List holds ", scalar @list, " numbers\n";

#@list = shuffle(@list);
# average value
my $avg = int( ((sum @list) / scalar @list) + 0.5);
# bytes required in fixed size (FOR encoding)
my $bytes = int(ceillog2(max @list) * scalar @list / 8);

if (0) {
  my $minsize = 1000000000;
  my $maxval = max @list;
  my $bitlim = ceillog2($maxval);
  foreach my $p1 (0 .. $bitlim) {
  foreach my $p2 (0 .. $bitlim) {
    next unless ($p1 + $p2) <= $bitlim;
    next unless BitStream::Code::StartStop::max_code_for_startstop([$p1,$p2]) >= $maxval;
    my $stream = stream_encode_array('wordvec', "ss($p1-$p2)", @list);
    my $len = $stream->len;
    if ($len < $minsize) {
      print "new min:  $len   ss($p1-$p2)\n";
      $minsize = $len;
    }
  }
  }
  foreach my $p1 (0 .. $bitlim) {
  foreach my $p2 (0 .. $bitlim) {
  foreach my $p3 (0 .. $bitlim) {
    next unless ($p1 + $p2 + $p3) <= $bitlim;
    next unless BitStream::Code::StartStop::max_code_for_startstop([$p1,$p2,$p3]) >= $maxval;
    my $stream = stream_encode_array('wordvec', "ss($p1-$p2-$p3)", @list);
    my $len = $stream->len;
    if ($len < $minsize) {
      print "new min:  $len   ss($p1-$p2-$p3)\n";
      $minsize = $len;
    }
  }
  }
  }
  foreach my $p1 (0 .. $bitlim) {
  foreach my $p2 (0 .. $bitlim) {
  foreach my $p3 (0 .. $bitlim) {
  foreach my $p4 (0 .. $bitlim) {
    next unless ($p1 + $p2 + $p3 + $p4) <= $bitlim;
    next unless BitStream::Code::StartStop::max_code_for_startstop([$p1,$p2,$p3,$p4]) >= $maxval;
    my $stream = stream_encode_array('wordvec', "ss($p1-$p2-$p3-$p4)", @list);
    my $len = $stream->len;
    if ($len < $minsize) {
      print "new min:  $len   ss($p1-$p2-$p3-$p4)\n";
      $minsize = $len;
    }
  }
  }
  }
  }
  foreach my $p1 (0 .. $bitlim) {
  foreach my $p2 (0 .. $bitlim) {
  foreach my $p3 (0 .. $bitlim) {
  foreach my $p4 (0 .. $bitlim) {
  foreach my $p5 (0 .. $bitlim) {
    next unless ($p1 + $p2 + $p3 + $p4 + $p5) <= $bitlim;
    next unless BitStream::Code::StartStop::max_code_for_startstop([$p1,$p2,$p3,$p4, $p5]) >= $maxval;
    my $stream = stream_encode_array('wordvec', "ss($p1-$p2-$p3-$p4-$p5)", @list);
    my $len = $stream->len;
    if ($len < $minsize) {
      print "new min:  $len   ss($p1-$p2-$p3-$p4-$p5)\n";
      $minsize = $len;
    }
  }
  }
  }
  }
  }
}


print "List (avg $avg, max ", max(@list), ", $bytes binary):\n";
time_list($_, @list) for (@encodings);

sub time_list {
  my $encoding = shift;
  my @list = @_;
  my $s1 = [gettimeofday];
  my $stream = stream_encode_array('wordvec', $encoding, @list);
  die "Stream ($encoding) construction failure" unless defined $stream;
  my $e1 = int(tv_interval($s1)*1_000_000);
  my $len = $stream->len;
  my $s2 = [gettimeofday];
  my @a = stream_decode_array($encoding, $stream);
  my $e2 = int(tv_interval($s2)*1_000_000);
  foreach my $i (0 .. $#list) {
      die "incorrect $encoding coding for $i" if $a[$i] != $list[$i];
  }
  printf "   %-14s:  %8d bytes  %8d uS encode  %8d uS decode\n", 
         $encoding, int(($len+7)/8), $e1, $e2;
  1;
}

