#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use List::Util qw(shuffle sum max);
use Time::HiRes qw(gettimeofday tv_interval);
use lib qw(../lib ../t/lib);
use BitStreamTest;

# Time with small, big, and mixed numbers.

sub ceillog2 {
  my $v = shift;
  $v--;
  my $b = 1;
  $b++  while ($v >>= 1);
  $b;
}

my @encodings = qw(unary gamma delta omega baer(-1));
#my @encodings = qw(gamma gg3 rice1 rice2 rice3 rice4 rice5 rice6 rice7 rice8 rice9 rice10 rice11 rice12 rice13 rice14);
#my @encodings = qw(gamma gg3 fib eg0 eg1 eg2 eg4 eg5 eg6);
#my @encodings = qw(unary gamma gg3 fib rice8 eg8);
#my @encodings = qw(gamma delta omega gg3 fib);
#my @encodings = qw(gol3 gol5 gol10 gg3 mgg3 mgg5 mgg10);
#my @encodings = qw|gamma delta omega fib fibc2 gg(3) mgg3 flag(2-5-8-20) sss(2-3-20)|;
#my @encodings = qw|gamma delta omega evenrodeh fib fibc2 binword(64) gg(11) deltagol(11) omegagol(11) ergol(11) fibgol(11) mgg3 eg(3) golomb(12) rice(3) sss(2-3-20) ss(5-6-9) ss(2-3-3-3-5-4)|;
#my @encodings = qw|gamma delta gg(11) eg(3)|;
#my @encodings = qw|unary gamma delta omega fib bvzeta(2) bvzeta(3) baer(0) baer(-1) baer(-2) baer(-3) baer(1) baer(2) baer(3)|;
#my @encodings = qw|baer(0)|;
#my @encodings = qw|fib fibc2|;
#my @encodings = qw|gamma delta omega levenstein bvzeta(2) bvzeta(5) ss(5-6-9) ss(5-5-4-6) ss(2-6-3-5-4) ss(2-3-3-3-5-4) ss(2-3-3-3-3-2-4)|;
#my @encodings = qw|sss(2-3-20) ss(0-1-3-5-12)|;

my $list_n = 2048;
my @list_small;
my @list_medium;
my @list_large;

{
  push @list_small, 0 for (1 .. $list_n);
  push @list_small, 1 for (1 .. ($list_n /2));
  push @list_small, 2 for (1 .. ($list_n /4));
  push @list_small, 3 for (1 .. ($list_n /8));
  push @list_small, 4 for (1 .. ($list_n /16));
  push @list_small, 4 for (1 .. ($list_n /32));
  push @list_small, 5 for (1 .. ($list_n /64));
  foreach my $n (6 .. 32) {
    push @list_small, $n for (1 .. ($list_n /128));
  }
}
print "Lists hold ", scalar @list_small, " numbers\n";
srand(15);
{
  foreach my $i (1 .. scalar @list_small) {
    # skew to smaller numbers
    my $d = rand(1);
    if    ($d < 0.25) { push @list_medium, int(rand(32)); }
    elsif ($d < 0.50) { push @list_medium, int(rand(256)); }
    elsif ($d < 0.75) { push @list_medium, int(rand(1024)); }
    else              { push @list_medium, int(rand(2048)); }
  }
  foreach my $i (1 .. scalar @list_small) {
    #push @list_large, 500+int(rand(65000));
    # skew to smaller numbers
    my $d = rand(1);
    if    ($d < 0.25) { push @list_large, int(rand(32)); }
    elsif ($d < 0.50) { push @list_large, int(rand(256)); }
    elsif ($d < 0.75) { push @list_large, int(rand(16000)); }
    elsif ($d < 0.98) { push @list_large, int(rand(65000)); }
    else              { push @list_large, int(rand(1_000_000)); }
  }
}

@list_small = shuffle(@list_small);
@list_medium = shuffle(@list_medium);
@list_large = shuffle(@list_large);
# average value
my $avg_small = int((sum @list_small) / scalar @list_small);
my $avg_medium = int((sum @list_medium) / scalar @list_medium);
my $avg_large = int((sum @list_large) / scalar @list_large);
# bytes required in fixed size (FOR encoding)
my $bytes_small = int(ceillog2(max @list_small) * scalar @list_small / 8);
my $bytes_medium = int(ceillog2(max @list_medium) * scalar @list_medium / 8);
my $bytes_large = int(ceillog2(max @list_large) * scalar @list_large / 8);

push @encodings, 'golomb(' . int(0.69 * $avg_medium) . ')';
push @encodings, 'golomb(' . int(0.69 * $avg_large) . ')';

print "Small (avg $avg_small, $bytes_small binary):\n";
  time_list($_, @list_small) for (@encodings);
print "Medium (avg $avg_medium, $bytes_medium binary):\n";
  time_list($_, @list_medium) for (@encodings);
print "Large (avg $avg_large, $bytes_large binary):\n";
  time_list($_, @list_large) for (@encodings);

sub time_list {
  my $encoding = shift;
  my @list = @_;
  my $s1 = [gettimeofday];
  my $stream = stream_encode_array('string', $encoding, @list);
  die "Stream ($encoding) construction failure" unless defined $stream;
  my $e1 = int(tv_interval($s1)*1_000_000);
  my $len = $stream->len;
  my $s2 = [gettimeofday];
  my @a = stream_decode_array($encoding, $stream);
  my $e2 = int(tv_interval($s2)*1_000_000);
  foreach my $i (0 .. $#list) {
      #die "incorrect $encoding coding for $i" if $a[$i] != $list[$i];
  }
  # convert total uS time into ns/value
  $e1 = int(1000 * ($e1 / scalar @list));
  $e2 = int(1000 * ($e2 / scalar @list));
  printf "   %-17s: %8d bytes  %6d ns encode  %6d ns decode\n", 
         $encoding, int(($len+7)/8), $e1, $e2;
  1;
}

