use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Data::BitStream',
    ABSTRACT     => "A class implementing a stream of bits and coding methods",
    VERSION_FROM => 'lib/Data/BitStream.pm', # finds $VERSION

    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl') : ()),

    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
       (AUTHOR         => 'Dana A Jacobsen <dana@acm.org>') : ()),

    PREREQ_PM => {
                     # I'm using subtest.  Could go back to 0.82 without it.
                     'Test::More'       => '0.94',
                     # Using just the import method of Exporter
                     'Exporter'         => '5.57',
                     # I normally use 0.93, but tested with RHEL6's 0.58
                     'Mouse'            => '0.58',
                     'Mouse::Role'      => '0.58',
                 },

   # I have not tested with any version of Perl previous to 5.6.2.  v5.6.2
   # does work, though is forced to 32-bit if it detects 64-bit arithmetic is
   # broken.  Data::BitStream::XS works fine on 5.6.2 because it is using C
   # for the bit operations.
   #
   # MIN_PERL_VERSION => 5.8.0,
);
