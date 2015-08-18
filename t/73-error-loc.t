#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;

use Moo::Role qw/apply_roles_to_object/;

my $error_regex = qr/error-loc\.t/;

require_ok 'Data::BitStream';

my $dbs = Data::BitStream->new(mode => 'ro');

throws_ok { $dbs->read($dbs->maxbits + 1) } $error_regex, 'read(maxbits + 1) should fail';
note "Message: $@";
throws_ok { $dbs->write(42, 8) } $error_regex, 'write to read-only should fail';
note "Message: $@";
throws_ok { $dbs->skip(-999999) } $error_regex, 'negative skip() should fail';
note "Message: $@";

# I'm not certain if this is the correct behavior, but a read() returns undef
# if there are exactly zero bytes left in the stream
$dbs = Data::BitStream->new();
$dbs->from_raw("\x00");
throws_ok { $dbs->read(32) } $error_regex, 'read past EOF should fail';
note "Message: $@";

done_testing;
