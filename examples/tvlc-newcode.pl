#!/usr/bin/perl

use BitStream::String;
use BitStream::Code::Baer;

my $stream = BitStream::String->new();
die unless defined $stream;
BitStream::Code::Baer->meta->apply($stream);

my $p = 0;
while (<>) {
  chomp;
  if (/^p\s*=?\s*(.*)/) { $p = $1; print "Set p to '$p'\n"; next; }
  next unless /^\d+$/;
  $stream->erase_for_write;
  $stream->put_baer($p, $_);
  my $s = $stream->to_string;
  print "        $s\n";
  $stream->rewind_for_read;
  my $d = $stream->get_baer($p);
  print "$d\n";
  print "\n";
}
