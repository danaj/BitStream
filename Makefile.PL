use ExtUtils::MakeMaker;

WriteMakefile1(
    NAME         => 'Data::BitStream',
    ABSTRACT     => "A class implementing a stream of bits and coding methods",
    VERSION_FROM => 'lib/Data/BitStream.pm', # finds $VERSION
    LICENSE      => 'perl',
    AUTHOR       => 'Dana A Jacobsen <dana@acm.org>',

    PREREQ_PM => {
                     # I'm using subtest.  Could go back to 0.82 without it.
                     'Test::More'       => '0.94',
                     # Using just the import method of Exporter
                     'Exporter'         => '5.57',
                     # I normally use 0.93, but tested with RHEL6's 0.58
                     'Mouse'            => '0.58',
                     'Mouse::Role'      => '0.58',
                 },

    META_MERGE => {
                    recommends => { 'Data::BitStream::XS' => 0.04, },
                    optional_features => {
                          bitvec =>  {
                              description => 'The Bit::Vector implementation',
                              requires => { 'Bit::Vector' => 0, },
                          },
                          mpxs =>  {
                              description => 'Fast primes for Goldbach codes, if Data::BitStream::XS is not available',
                              requires => { 'Math::Prime::XS' => 0, },
                          },
                          mpfs =>  {
                              description => 'Fast primes for Goldbach codes, if Data::BitStream::XS is not available',
                              requires => { 'Math::Prime::FastSieve' => 0, },
                          },
                    },
                  },

    # I have not tested with any version of Perl previous to 5.6.2.  v5.6.2
    # does work, though is forced to 32-bit if it detects 64-bit arithmetic is
    # broken.  Data::BitStream::XS works fine on 5.6.2 because it is using C
    # for the bit operations.
    MIN_PERL_VERSION => 5.006002,

);

sub WriteMakefile1 { 
  my %params = @_;
  my $eumm_version = $ExtUtils::MakeMaker::VERSION;
  $eumm_version = eval $eumm_version;

  if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
      #EUMM 6.5502 has problems with BUILD_REQUIRES
      $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
      delete $params{BUILD_REQUIRES};
  }
  delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
  delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
  delete $params{META_MERGE} if $eumm_version < 6.46;
  delete $params{META_ADD} if $eumm_version < 6.46;
  delete $params{LICENSE} if $eumm_version < 6.31;
  delete $params{AUTHOR} if $] < 5.005;
  delete $params{ABSTRACT_FROM} if $] < 5.005;
  delete $params{BINARY_LOCATION} if $] < 5.005;

  WriteMakefile(%params);
}
