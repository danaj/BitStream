#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use List::Util qw(shuffle sum max);
use Time::HiRes qw(gettimeofday tv_interval);
use lib qw(../lib ../t/lib);
use Data::BitStream::WordVec;
use Data::BitStream::String;
use Data::BitStream::Vec;
use Data::BitStream::BitVec;

sub ceillog2 {
  my $v = shift;
  $v--;
  my $b = 1;
  $b++  while ($v >>= 1);
  $b;
}

my $list_n = 40000;
my @list;
push @list, int(rand(1000))  for (1 .. $list_n);


my %s1 = (
  'string ', Data::BitStream::String->new,
  'wordvec', Data::BitStream::WordVec->new,
  #'vec    ', Data::BitStream::Vec->new,
  #'bitvec ', Data::BitStream::BitVec->new,
);
my %s2 = (
  'string ', Data::BitStream::String->new,
  'wordvec', Data::BitStream::WordVec->new,
  #'vec    ', Data::BitStream::Vec->new,
  #'bitvec ', Data::BitStream::BitVec->new,
);

foreach my $s1name (keys %s1) {
  my $s1 = $s1{$s1name};
  $s1->erase_for_write;
  $s1->put_gamma($_) for @list;
}
my $put_master = Data::BitStream::String->new;
$put_master->write(5, 17);
$put_master->put_gamma($_) for @list;
$put_master->write_close;

foreach my $s1name (keys %s1) {
  foreach my $s2name (keys %s2) {
    time_copy("copy $s1name to $s2name", $s1{$s1name}, $s2{$s2name}, @list);
    time_put( "put  $s1name to $s2name", $s1{$s1name}, $s2{$s2name}, @list);
  }
}


sub time_put {
  my $text = shift;
  my $s1 = shift;
  my $s2 = shift;

  my $t1 = [gettimeofday];
  #$s2->put_string($s1->to_string);
  $s2->write(5,17);
  $s2->put_stream($s1);
  my $e1 = int(tv_interval($t1)*1_000_000);
  printf("%11s  %7.3fms\n", $text, $e1/1000);
  die "copy didn't work" unless $s2->to_string eq $put_master->to_string;
  $s2->erase_for_write;
  1;
}

sub time_copy {
  my $text = shift;
  my $s1 = shift;
  my $s2 = shift;

  my $t1 = [gettimeofday];
  $s2->from_string($s1->to_string);
  my $e1 = int(tv_interval($t1)*1_000_000);
  printf("%11s  %7.3fms\n", $text, $e1/1000);
  die "copy didn't work" unless $s1->to_string eq $s2->to_string;
  $s2->erase_for_write;
  1;
}

