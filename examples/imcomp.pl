#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);
use FindBin;  use lib "$FindBin::Bin/../lib";
use Data::BitStream;
use Getopt::Long;
use Storable qw(dclone);
use POSIX;
use Imager;

#
# Very simple example lossless image compressor.
#
# Examples:
# 
#  Compress art.ppm -> c.bsc using defaults
#
#      perl imcomp.pl  -c  -i art.ppm  -o c.bsc
#
#  Compress art.ppm -> c.bsc with custom settings
#
#      perl imcomp.pl  -c  -predict gap  -transform rct \
#                          -code 'startstop(0-1-2-3-3-3-3)' \
#                          -i art.ppm  -o c.bsc
#
#  Decompress c.bsc -> c.ppm
#
#   perl imcomp.pl  -d  -i c.bsc  -o c.ppm
#
# Note: This is for demonstration.  It runs ~100x slower than similar C code,
# and it is quite a bit simpler than systems like JPEG-LS, CALIC, JPEG2000,
# HDPhoto, etc.  It will typically beat gzip, bzip2, lzma however.  The speed
# can be improved with some work, mostly in the Data::BitStream library.
#
# Note that without any run length encoding, this sort of compression will be
# be limited to 1 bit per pixel, or a maximum 8x compression ratio.
#
# BUGS / TODO:
#       - encoding method is extremely simplistic
#       - contexts would help a lot
#       - Should read from stdin and write to stdout if desired.

sub die_usage {
  my $usage =<<EOU;
Usage:
         -c                compress
         -d                decompress
         -i <file>         input file  (image for compress, bsc for decompress)
         -o <file>         output file (image for decompress, bsc for compress)

    Optional arguments for compression:

         [-code <code>]    encoding method for pixel deltas:
                               Gamma (default), Delta, Omega, Fibonacci,
                               EvenRodeh, Levenstein, FibC2,
                               Rice(n), Golomb(n), GammaGolomb(n), ExpGolomb(n),
                               StartStop(#-#-...), etc.
         [-transform <tf>] use a lossless color transform for color images:
                               YCoCg  Malvar   (default)
                               RCT    JPEG2000
                               RGB    No transform
         [-predict <pred>] use a particular pixel prediction method
                               MED    JPEG-LS MED (default)
                               DARC   Memon/Wu simple
                               GAP    CALIC gradient
                               GED2   Avramović / Savić
                               DJMED  median of linear predictors
EOU

  die $usage;
}

# TODO: Change this to a GetOptions hash
my $code;
my $transform;
my $predictor;
my $c = 0;
my $d = 0;
my $input_file;
my $output_file;
GetOptions('help|usage|?' => sub { die_usage() },
           'c' => \$c,
           'd' => \$d,
           'i=s' => \$input_file,
           'o=s' => \$output_file,
           'code=s' => \$code,
           'predict=s' => \$predictor,
           'transform=s' => \$transform);

die_usage if ($c && $d) || (!$c && !$d);
die_usage unless defined $input_file && defined $output_file;

# standardize transform names
# Clean this.
TODO: 
if (defined $transform) {
  if    (uc $transform eq 'YCOCG') { $transform = 'YCoCg'; }
  elsif (uc $transform eq 'RCT'  ) { $transform = 'RCT';   }
  elsif (uc $transform eq 'RGB'  ) { $transform = 'RGB';   }
  elsif (uc $transform eq 'BGR'  ) { $transform = 'BGR';   }
  else { die "Unknown transform: $transform"; }
}


# TODO: Consider dispatch table
sub predict {
  my ($x, $y, $width, $r, $rn, $rnn) = @_;
  die unless defined $predictor;
  my $pred;

  my ($w, $n);
  $w  = $r ->[$x-1] if $x > 0;
  $n  = $rn->[$x  ] if $y > 0;
  # Simple 1-D edge cases
  return 0  if $x == 0 && $y == 0;
  return $w if $y == 0;
  return $n if $x == 0;

  my $nw = $rn->[$x-1];

  if ($predictor eq 'DARC') {
    my $gv = abs($w - $nw);
    my $gh = abs($n - $nw);
    return $n if $gv + $gh == 0;
    my $alpha = $gv / ($gv + $gh);
    $pred = $alpha * $w + (1-$alpha) * $n;
    return POSIX::floor($pred);
  }

  # Use MED if our window isn't large enough (no nn, ww, ne)
  if ( ($predictor eq 'MED') || ($y == 1) || ($x == 1) || ($x == $width-1)) {
    my $maxwn = ($n > $w) ? $n : $w;
    my $minwn = ($n < $w) ? $n : $w;
    if    ($nw >= $maxwn) { $pred = $minwn; }
    elsif ($nw <= $minwn) { $pred = $maxwn; }
    else                  { $pred = $n + $w - $nw; }
    return $pred;
  }

  my $ww = $r  ->[$x-2];
  my $ne = $rn ->[$x+1];
  my $nn = $rnn->[$x  ];
  my $nne= $rnn->[$x+1];

  if ($predictor eq 'DJMED') {
    my $T = 16;
    my $gv = abs($nw - $w) + abs($nn - $n);
    my $gh = abs($ww - $w) + abs($nw - $n);
    if    (($gv-$gh) >  $T) { $pred = $w; }
    elsif (($gv-$gh) < -$T) { $pred = $n; }
    else {
      # predict the median of three linear predictors
      my $p1 = $n + $w - $nw;
      my $p2 = $n - ($nn - $n);
      my $p3 = $w - ($ww - $w);
      $pred = ( $p1<$p2 ? ($p2<$p3 ? $p2
                                   : ($p1<$p3 ? $p3 : $p1))
                        : ($p3<$p2 ? $p2
                                   : ($p3<$p1 ? $p3 : $p1)) );
    }
    return $pred;
  }

  if ($predictor eq 'GAP') {
    # GAP (Gradient Adjusted Predictor) from CALIC
    my $dh = abs($w - $ww) + abs($n - $nw) + abs($ne - $n);
    my $dv = abs($w - $nw) + abs($n - $nn) + abs($ne - $nne);
    return $n if $dh - $dv > 80;
    return $w if $dv - $dh > 80;
    $pred = ($w + $n)/2 + ($ne - $nw)/4;
    if    ($dh-$dv > 32) { $pred = (  $pred + $n) / 2; }
    elsif ($dv-$dh > 32) { $pred = (  $pred + $w) / 2; }
    elsif ($dh-$dv >  8) { $pred = (3*$pred + $n) / 4; }
    elsif ($dv-$dh >  8) { $pred = (3*$pred + $w) / 4; }
    return POSIX::floor($pred);
  }

  if ($predictor eq 'GED2') {
    my $T = 8;
    my $gv = abs($nw - $w) + abs($nn - $n);
    my $gh = abs($ww - $w) + abs($nw - $n);
    if    ($gv - $gh >  $T) { $pred = $w; }
    elsif ($gv - $gh < -$T) { $pred = $n; }
    else                    { $pred = $n + $w - $nw; }
    return $pred;
  }

  die "Unknown predictor: $predictor";
}


# It would be great to just use Imager's matrix convert for the color
# transforms, but it clamps the results to 0-255, which makes it useless.
# Too bad, because it's easy and fast.

sub decor_colors {
  my $to = shift;
  my $decor = shift;
  my $rcolors = shift;

  return if $to eq 'RGB';

  my $p = @{$rcolors->[0]};
  return if $p == 1;
  die unless $p == 3;

  my $w = @{$rcolors};

  my(@ys,@us,@vs);
  foreach my $x (0 .. $w-1) {
    my($r,$g,$b) = @{$rcolors->[$x]};
    my($y,$u,$v) = ($r,$g,$b);
    if ($to eq 'RCT') { # JPEG2000 lossless integer transform
      if ($decor) {
        $y =  POSIX::floor( ($r + 2*$g + $b) / 4 );
        $u =  ($r-$g);
        $v =  ($b-$g);
      } else {
        $g = $y - POSIX::floor( ($u+$v)/4 );
        $r = $u + $g;
        $b = $v + $g;
      }
    } elsif ($to eq 'YCoCg') { # Malvar's lossless, from SPIE'08
      if ($decor) {
        my $co = $r - $b;
        my $t = $b + POSIX::floor($co/2);
        my $cg = $g - $t;
        $y = $t + POSIX::floor($cg/2);
        $u = $co;
        $v = $cg;
      } else {
        my $co = $u;
        my $cg = $v;
        my $t = $y - POSIX::floor($cg/2);
        $g = $cg + $t;
        $b = $t - POSIX::floor($co/2);
        $r = $b + $co;
      }
    } elsif ($to eq 'BGR') { # Just for testing
      if ($decor) {
        ($y,$u,$v) = ($b,$g,$r);
      } else {
        ($r,$g,$b) = ($v,$u,$y);
      }
    } else {
      die "Unknown conversion space: $to";
    }
    if ($decor) {
      @{$rcolors->[$x]} = ($y,$u,$v);
    } else {
      @{$rcolors->[$x]} = ($r,$g,$b);
    }
  }
}


if ($c) {
  # Use Imager to get the file
  my $image = Imager->new;
  my $idata;
  $image->read( file => $input_file,  data => \$idata)  or die $image->errstr;
  # Image header:
  my ($width, $height, $planes, $mask) = $image->i_img_info;

  # Set defaults
  $code      = 'Gamma'  unless defined $code;
  $predictor = 'MED'    unless defined $predictor;
  $predictor = uc $predictor;
  $transform = 'YCoCg'  unless defined $transform;

  my $method = "$code/$predictor";
  $method .= "/$transform" if $planes > 1;

  # Start up the stream
  my $stream = Data::BitStream->new(
        file => $output_file,
        fheader => "BSC $method w$width h$height p$planes",
        mode => 'w' );

  my @colors;   # [$y]->[$x]->[$p]
  foreach my $y (0 .. $height-1) {
    $colors[$y-3] = undef if $y >= 3;   # remove unneeded y values

    # Simple code for single-plane.  Doing this to better illustrate the basic
    # predict-encode operation without getting bogged down in Imager and color
    # plane decorrolation.
    if ($planes == 1) {
      # Get scanline from imager, and extract the 8-bit color value
      $colors[$y] = [ map { ($_->rgba)[0] }
                          $image->getscanline(y=>$y, type=>'8bit') ];

      my @val   = @{$colors[$y]};
      my @nval  = @{$colors[$y-1]};
      my @nnval = @{$colors[$y-2]};
      die "short code read" unless scalar @val == $width;

      my @deltas = ();
      foreach my $x (0 .. $width-1) {
        my $pixel  = $val[$x];

        # 1) Predict this pixel.
        my $predict = predict($x, $y, $width, \@val, \@nval, \@nnval);

        # 2) encode the delta mapped to an unsigned number
        my $delta  = $pixel - $predict;
        my $udelta = ($delta >= 0)  ?  2*$delta  :  -2*$delta-1;
        push @deltas, $udelta;
      }
      $stream->code_put($code, @deltas);
      next;
    }

    {
      # Get a scanline of colors and convert to RGB
      my @rgbcolors;
      foreach my $c ( $image->getscanline(y => $y, type => '8bit') ) {
        push @rgbcolors, [ ($c->rgba)[0 .. $planes-1] ]
      }
      die "short image read" unless scalar @rgbcolors == $width;
      $colors[$y] = [ @rgbcolors ];
    }

    # Decorrelate the color planes for better compression
    decor_colors($transform, 1, $colors[$y]);

    #foreach my $x (0 .. $width-1) { print "[$y,$x] ", join(' ',@{$ycolors[$x]}), "\n"; }

    foreach my $p (0 .. $planes-1) {
      my @val   =              map { $_->[$p] } @{$colors[$y  ]};
      my @nval  = ($y > 0)  ?  map { $_->[$p] } @{$colors[$y-1]}  :  ();
      my @nnval = ($y > 1)  ?  map { $_->[$p] } @{$colors[$y-2]}  :  ();

      my @deltas = ();
      foreach my $x (0 .. $width-1) {
        my $pixel  = $val[$x];

        # 1) Predict this pixel.
        my $predict = predict($x, $y, $width, \@val, \@nval, \@nnval);

        # 2) encode the delta mapped to an unsigned number
        my $delta  = $pixel - $predict;
        my $udelta = ($delta >= 0)  ?  2*$delta  :  -2*$delta-1;
        push @deltas, $udelta;
      }
      $stream->code_put($code, @deltas);
    }
  }

  # Close the stream, which will flush the file
  $stream->write_close;
  my $origsize = $width * $height * $planes;
  my $compsize = int( ($stream->len + 7) / 8);
  printf "origsize: %d   %s compressed size: %d   ratio %.1fx\n",
         $origsize, $method, $compsize, $origsize / $compsize;
}


if ($d) {
  # Open the bitstream file with one header line
  my $stream = Data::BitStream->new( file => $input_file,
                                     fheaderlines => 1,
                                     mode => 'ro' );

  # Parse the header line
  my $header = $stream->fheader;
  die "$input_file is not a BSC compressed image\n" unless $header =~ /^BSC /;

  my ($method, $width, $height, $planes) =
              $header =~ /^BSC (\S+) w(\d+) h(\d+) p(\d+)/;
  print "$width x $height x $planes image compressed with $method encoding\n";

  ($code, $predictor, $transform) = split('/', $method);
  die "No code found in header" unless defined $code;
  die "No predictor found in header" unless defined $predictor;
  die "No transform found in header" unless $planes == 1 || defined $transform;

  # Start up an Imager object
  my $image = Imager->new( xsize    => $width,
                           ysize    => $height,
                           channels => $planes);

  my @colors;   # [$y]->[$x]->[$p]
  foreach my $y (0 .. $height-1) {
    $colors[$y-3] = undef if $y >= 3;   # remove unneeded y values

    my @ycolors;  # ycolors[$x]->[$p];
    foreach my $p (0 .. $planes-1) {
      # get a line worth of absolute deltas and convert them to signed
      my @deltas = map { (($_&1) == 0)  ?  $_ >> 1  :  -(($_+1) >> 1); }
                   $stream->code_get($code, $width);
      die "short code read" unless scalar @deltas == $width;

      my @val   = ();
      my @nval  = ($y > 0)  ?  map { $_->[$p] } @{$colors[$y-1]}  :  ();
      my @nnval = ($y > 1)  ?  map { $_->[$p] } @{$colors[$y-2]}  :  ();

      foreach my $x (0 .. $width-1) {
        my $predict = predict($x, $y, $width, \@val, \@nval, \@nnval);
        my $pixel = $predict + $deltas[$x];
        push @val, $pixel;
        push @{$ycolors[$x]}, $pixel;
      }
    }
    $colors[$y] = [@ycolors];

    # set the scanline
    {
      my @icolors;
      if ($planes == 1) {
        @icolors = map { Imager::Color->new(gray => $_->[0]); } @ycolors;
      } else {
        # operate on a copy of colors so we ensure it's not changed.
        my $ycolors_copy = dclone($colors[$y]);

        # Reverse decorrolation
        decor_colors($transform, 0, $ycolors_copy);

        foreach my $x (0 .. $width-1) {
          my($r,$g,$b) = @{$ycolors_copy->[$x]};
          #print "[$y,$x] $r $g $b\n";
          push @icolors, Imager::Color->new(r=>$r, g=>$g, b=>$b);
        }
      }
      $image->setscanline( y => $y,  type => '8bit',  pixels => \@icolors );
    }
  }

  # Write the final image
  $image->write( file => $output_file)  or die $image->errstr;
}
