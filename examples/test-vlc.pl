#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
use Data::Dumper;

use BitStream::String;
use BitStream::Vec;
use BitStream::BitVec;
#use BitStream::ChunkString;

sub new_stream {
  BitStream::String->new();
}

sub encode_stream {
  my $encoding = lc shift;
  die "Unknown encoding" unless $encoding =~ /^(?:unary|gamma|gg3)$/;
  my $stream = new_stream;
  foreach my $d (@_) {
    die  "Numbers must be >= 0 for unsigned unary coding" if $d < 0;
    warn "Unary coding not recommended for large numbers ($d)" if $d > 100000;
    if ($encoding eq 'unary') {
      $stream->put_unary($d);
    } elsif ($encoding eq 'gamma') {
      $stream->put_gamma($d);
    } elsif ($encoding eq 'gg3') {
      $stream->put_gg3($d);
    }
  }
  return $stream;
}

sub decode_stream {
  my $encoding = lc shift;
  my $stream = shift;

  die "Unknown encoding" unless $encoding =~ /^(?:unary|gamma|gg3)$/;
  $stream->rewind_for_read();
  my @v;
  my $val;
  if ($encoding eq 'unary') {
    push @v, $val  while (defined ($val = $stream->get_unary()));
  } elsif ($encoding eq 'gamma') {
    push @v, $val  while (defined ($val = $stream->get_gamma()));
  } elsif ($encoding eq 'gg3') {
    push @v, $val  while (defined ($val = $stream->get_gg3()));
  }
  wantarray  ?  @v  :  $v[0];
}

#my @encodings = qw(unary gamma gg3);
my @encodings = qw(gamma);

if (0) {
  foreach my $n (0 .. 12) {
    my $wstream = new_stream;
    $wstream->put_unary($n);
    my($str, $soffset) = $wstream->to_string();
    say "unary of $n is $str";

    my $rstream = new_stream;
    $rstream->from_string($str, $soffset);
    my $val = $rstream->get_unary();
    say "I got value $val";
    die "Wrong unary code" unless $val == $n;
    die "Didn't get end of stream" if defined $rstream->get_unary();
  }
  foreach my $n (0 .. 12) {
    my $wstream = new_stream;
    $wstream->put_gamma($n);
    my($str, $soffset) = $wstream->to_string();
    say "gamma of $n is $str";

    my $rstream = new_stream;
    $rstream->from_string($str, $soffset);
    my $val = $rstream->get_gamma();
    say "I got value $val";
    die "Wrong gamma code" unless $val == $n;
    die "Didn't get end of stream" if defined $rstream->get_gamma();
  }
}

foreach my $encoding (@encodings) {
  my @data = (0, 4, 5, 10, 317, 12, 3, 8, 7, 213);
  my $stream = encode_stream($encoding, @data);
  #say Data::Dumper->Dump( [$stream], ['after encode returns'] );
  my @a = decode_stream($encoding, $stream);
  printf "%-6s: @a\n", $encoding;
  foreach my $i (0 .. $#data) {
    die "incorrect $encoding coding for $i" if $a[$i] != $data[$i];
  }
}

foreach my $encoding (@encodings) {
  my $stream = encode_stream($encoding, 12);
  my $a = decode_stream($encoding, $stream);
  printf "%-6s: $a\n", $encoding;
}

if (1) {
  my $n = 10000;
  my @testa = (0 .. $n);

  foreach my $encoding (@encodings) {
    printf "%-6s for 0 .. $n  ", $encoding;

    my $stream = encode_stream($encoding, @testa);
    say "   length is ", $stream->len;
    my @resulta = decode_stream($encoding, $stream);

    foreach my $i (0 .. $#testa) {
      die "incorrect $encoding coding for $i" if $resulta[$i] != $testa[$i];
    }
  }
}

if (1) {
  my $n = 5000;
  my @a = (0 .. $n);
  my $stream = new_stream;
  $stream->write(11, $_) for (@a);
  $stream->rewind_for_read;
  while (defined (my $i = $stream->read(11))) {
    die unless $i == $a[$i];
  }
}
