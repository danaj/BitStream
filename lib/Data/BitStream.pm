package Data::BitStream;
# TODO: use 5.???

use strict;
use warnings;

our $VERSION = '0.01';

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Data::BitStream ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);


#use namespace::clean -except => 'meta';

# Pick one implementation as the default.
#
# String is usually fastest, but more memory than the others (1 byte per bit).

# BitVec (using Bit::Vector) is usually next fastest, but has the Bit::Vector
# prerequisite that I don't want to add just to use this package.
#
# WordVec can be close to BitVec in most operations.
#
# Vec is rather slow.

use Data::BitStream::WordVec;
use Mouse;
extends 'Data::BitStream::WordVec';
no Mouse;

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Data::BitStream - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Data::BitStream;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Data::BitStream, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Dana A Jacobsen, E<lt>dana@acm.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Dana A Jacobsen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
