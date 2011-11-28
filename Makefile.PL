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

   # 64-bit seems broken in Perl 5.6.2 on the 32-bit systems I have (and at
   # least one CPAN Tester shows the same).  Try:
   #     perl -e 'die if 18446744073709550593 == ~0'
   # That inexplicably dies on 64-bit 5.6.2.  It works fine on 5.8.0 and later.
   #
   # Most of the module can be made to work by forcing maxbits to 32 if we're
   # pre-5.8.0 (which I have done).  However there is a lot of work to do in
   # the Code modules.  I've made enough changes so only the range tests fail.
   # Basically it all works fine unless you're using a 64-bit pre-5.8.0 Perl
   # on a 32-bit system compiled with 64-bit ints, and want to store 0xFFFFFFFF
   # with interesting codes such as Gamma, Omega, etc.
   #
   # Given the age of 5.6.2, I've decided the best solution for now is to
   # require a more modern (only 10 years old) Perl.
   # I have not tested any of the 5.7.x versions.
   #
   # Note:  Data::BitStream::XS works fine on 5.6.2 because it is using C for
   #        these operations.  You should be ok either using that module, or
   #        using this module with D::B::XS installed.
   #
   MIN_PERL_VERSION => 5.8.0,
);
