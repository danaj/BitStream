#!/usr/bin/perl
use strict;
use warnings;

use lib qw(../lib ../t/lib);
use Data::BitStream;
use Data::BitStream::Code::Baer;
use Data::BitStream::Code::Escape;

my $stream = Data::BitStream->new();
die unless defined $stream;
Data::BitStream::Code::Baer->meta->apply($stream);
Data::BitStream::Code::Escape->meta->apply($stream);

my $p = 0;
while (<>) {
  chomp;
  # Allows setting the parameter via:  p=....
  if (/^p\s*=?\s*\[(.*)\]/) { $p = [split(/-|,|\s+/,$1)]; print "Set p to '[",join(",",@$p),"]'\n"; next; }
  if (/^p\s*=?\s*(.*)/)     { $p = $1; print "Set p to '$p'\n"; next; }
  # Ignore non-digit input
  next unless /^\d+$/;
  # Save the value
  my $v = $_;

  $stream->erase_for_write;
  $stream->put_baer($p, $v);
  #$stream->put_escape($p, $v);

  my $s = $stream->to_string;
  print "        $s\n";

  $stream->rewind_for_read;
  my $d = $stream->get_baer($p);
  #my $d = $stream->get_escape($p);
  if ($d != $v) {
    print "DECODED:  $d instead of $v\n";
  }
}
