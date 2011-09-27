#!/usr/bin/perl
use strict;
use warnings;
use lib qw(../lib ../t/lib);
use Data::BitStream;
use Data::BitStream::Code::BoldiVigna;
use Data::BitStream::Code::Baer;

sub new_stream {
  my $stream = Data::BitStream->new();
  Data::BitStream::Code::BoldiVigna->meta->apply($stream);
  Data::BitStream::Code::Baer->meta->apply($stream);
  return $stream;
}

sub string_of {
  my $encoding = lc shift;
  my $d = shift;
  my $stream = new_stream;
  if    ($encoding eq 'unary')     { $stream->put_unary($d);    }
  elsif ($encoding eq 'gamma')     { $stream->put_gamma($d);    }
  elsif ($encoding eq 'delta')     { $stream->put_delta($d);    }
  elsif ($encoding eq 'omega')     { $stream->put_omega($d);    }
  elsif ($encoding eq 'fib')       { $stream->put_fib($d);      }
  elsif ($encoding eq 'fibc2')     { $stream->put_fib_c2($d);   }
  elsif ($encoding eq 'lev')       { $stream->put_levenstein($d);     }
  elsif ($encoding =~ /bvzeta(\d+)/){$stream->put_boldivigna($1, $d); }
  elsif ($encoding =~ /baer\((.+)\)/) { $stream->put_baer($1, $d); }
  elsif ($encoding =~ /eg(\d+)/)   { $stream->put_expgolomb($1, $d);  }
  elsif ($encoding =~ /gol(\d+)/)  { $stream->put_golomb($1, $d);     }
  elsif ($encoding =~ /rice(\d+)/) { $stream->put_rice($1, $d);       }
  else  { die "Unknown encoding: $encoding"; }
  my $str = $stream->to_string();
  $str;
}

#foreach my $n (0 .. 1000000) { die "$n" unless (1+length(string_of('omega',$n))) == length(string_of('lev',$n+1)); }

if (1) {
  #my @encodings = qw|Gamma BVZeta2 BVZeta3 BVZeta4 Delta|;
  #my @encodings = qw|Baer(-2) Baer(-1) Baer(0) Baer(1) Baer(2)|;
  my @encodings = qw|Gamma Delta Omega Fib Lev|;
  printf "%5s  " . (" %-11s" x scalar @encodings) . "\n", 'N', @encodings;
  printf "%5s  ", '-' x 5;
  printf " %-11s", '-' x 11 for (@encodings);
  print "\n";
  foreach my $n (0 .. 20) {
  #foreach my $n (0..16, 99, 999, 999_999) {
    printf "%5d  ", $n;
    foreach my $encoding (@encodings) {
      my $str = string_of($encoding, $n);
      printf " %-11s", $str;
    }
    print "\n";
  }
}
