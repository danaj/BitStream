#!/usr/bin/perl
use strict;
use warnings;

use Test::More;


my @types = qw(string vector bitvector wordvec);
plan tests => scalar @types;

# We require the string implementation, and will test the Vec and BitVec
# versions if they're available.

use Data::BitStream::String;

my %stream_constructors = (
  'string', sub { return Data::BitStream::String->new(); },
);
if (eval "require Data::BitStream::Vec") {
  $stream_constructors{'vector'} = sub { return Data::BitStream::Vec->new(); };
}
if (eval "require Data::BitStream::BitVec") {
  $stream_constructors{'bitvector'} = sub { return Data::BitStream::BitVec->new(); };
}
if (eval "require Data::BitStream::WordVec") {
  $stream_constructors{'wordvec'} = sub { return Data::BitStream::WordVec->new(); };
}


sub new_stream {
  my $type = lc shift;
  $type =~ s/[^a-z]//g;
  my $constructor = $stream_constructors{$type};
  if (defined $constructor) {
    return $constructor->();
  } else {
    return undef;
  }
}

sub test_type {
  my $type = shift;
  my $stream = shift;
  die unless defined $type and defined $stream;

  my $status;
  my $v;

  # Test basic operations that should succeed
  ok($stream->maxbits >= 32, "maxbits >= 32");

  $status = ($stream->writing) && ($stream->len == 0) && ($stream->pos == 0);
  ok($status, "newly opened stream");

  $stream->write(1,1);
  $stream->write(3,5);
  $status = $stream->writing && $stream->len == 4;
  ok($status, "simple write");

  $stream->write_close;
  $status = !$stream->writing && $stream->len == 4 && $stream->pos == 4;
  ok($status, "write close");

  $stream->rewind;
  $status = !$stream->writing && $stream->len == 4 && $stream->pos == 0;
  ok($status, "rewind");

  $v = $stream->read(4);
  $status = $v == 0xD && !$stream->writing && $stream->len == 4 && $stream->pos == 4;
  ok($status, "read");

  $stream->rewind;
  $stream->write_open;
  $status = $stream->writing && $stream->len == 4;
  ok($status, "write open");

  $stream->put_unary(4);
  $status = $stream->writing && $stream->len == 9;
  ok($status, "write unary");

  $stream->rewind_for_read;
  $status = !$stream->writing && $stream->len == 9 && $stream->pos == 0;
  ok($status, "rewind for read");

  $v = $stream->readahead(2);
  $status = $v == 3 && !$stream->writing && $stream->len == 9 && $stream->pos == 0;
  ok($status, "readahead");

  # Unary is 000..1
  $v = $stream->read(9);
  $status = ($v == 0x1A1)
            && !$stream->writing && $stream->len == 9 && $stream->pos == 9;
  ok($status, "read");


  $stream->erase_for_write;
  $status = $stream->writing && $stream->len == 0;
  ok($status, "erase for write");

  $stream->put_unary1(7);
  $status = $stream->writing && $stream->len == 8;
  ok($status, "write unary1");
  $stream->rewind_for_read;
  $status = !$stream->writing && $stream->len == 8 && $stream->pos == 0;
  ok($status, "rewind for read");
  # Unary1 is 111..0
  $v = $stream->get_unary1(-1);
  $status = ($v == 7) 
            && !$stream->writing && $stream->len == 8 && $stream->pos == 8;
  ok($status, "read");

  $stream->erase_for_write;
  $status = $stream->writing && $stream->len == 0;
  ok($status, "erase for write");

  $stream->put_gamma(13);
  $status = $stream->writing && $stream->len == 7;
  ok($status, "put gamma 13");

  {
    my $str = $stream->to_string;
    $status = ($str eq '0001110') && !$stream->writing && $stream->len == 7;
    ok($status, "to string returned '0001110'");
  }

  {
    my $vec = $stream->to_raw;
    # the '0001110' comes back as '0001110[0...]'
    #printf "veclen = %d (want 1)   vec = '%s' 0x%x (want 0x1C)\n",
    #       length($vec), unpack("b8", $vec), vec($vec,0,8);
    $status = (length($vec) >= 1) && (length($vec) <= 4)
              && (vec($vec,0,8) == 0x1C)
              && !$stream->writing && $stream->len == 7;
    ok($status, "to raw returned 0x0E");
  }

  $stream->from_string('000000011111010');
  $status = !$stream->writing && $stream->len == 15 && $stream->pos == 0;
  ok($status, "from string '000000011111010'");

  $stream->rewind_for_read;
  $v = $stream->get_gamma;
  $status = ($v == 249)
            && !$stream->writing && $stream->len == 15 && $stream->pos == 15;
  ok($status, "read gamma returned 249");

  {
    my $vec = '';
    vec($vec, 0, 8) = 0xC5;
    $stream->from_raw($vec, 8);
    $status = !$stream->writing && $stream->len == 8 && $stream->pos == 0;
    ok($status, "from raw 0xC5 (8)");

    $vec = $stream->to_raw;
    $status = (length($vec) >= 1) && (length($vec) <= 4)
              && (vec($vec,0,8) == 0xC5)
              && !$stream->writing && $stream->len == 8;
    ok($status, "to raw returned 0xC5 (8)");
  }

  {
    my $success = 1;
    $stream->erase_for_write;
    foreach my $n (0 .. 65) {
      $stream->put_unary( 2*$n+0 );
      $stream->put_gamma( 2*$n+1 );
    }
    $status = $stream->len == 5106;
    ok($stream->len == 5106, "put sequence of numbers using unary and gamma");
    $stream->rewind_for_read;
    foreach my $n (0 .. 65) {
      if ($stream->get_unary() != (2*$n+0)) { $success = 0; last; }
      if ($stream->get_gamma() != (2*$n+1)) { $success = 0; last; }
    }
    ok($success, "correctly read sequence");
  }

  done_testing();
}

foreach my $type (@types) {
  SKIP: {
    my $stream = new_stream($type);
    skip "$type implementation not available", 1 unless defined $stream;

    subtest "$type implementation" => sub { test_type($type, $stream) };
  }

}

done_testing();
