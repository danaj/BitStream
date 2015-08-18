#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

use Moo::Role qw/apply_roles_to_object/;

sub test_case(&);

require_ok 'Data::BitStream';

my $dbs;

# write a single '1' bit; the result should be 1 byte long.
test_case { $dbs->write(1, 1) };
# write a single '1' bit; the result should be 1 byte long.
test_case { $dbs->write(1, 0) };

sub test_case(&) {
	my ($sub) = @_;
	$dbs = Data::BitStream->new();
	$sub->($dbs);
	my $bits = $dbs->len;
	my $expected_length = int(($bits + 7) / 8);
	my $raw_data = $dbs->to_raw();
	my $actual_length = length($raw_data);
	is($actual_length, $expected_length, "Expecting $bits bits to take $expected_length bytes");
}

done_testing;
