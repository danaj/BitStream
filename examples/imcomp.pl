#!/usr/bin/perl
use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);
use FindBin;  use lib "$FindBin::Bin/../lib";
use Data::BitStream;
use Getopt::Long;
use Imager;

#
# Very simple example image compressor
#
# BUGS / TODO:
#       - only grayscale supported
#       - no headers for compressed image including no width/height info
#       - decompression not supported
#       - encoding method is extremely simplistic
#       - The MED predictor is simple but not as good as GAP, P6, GED2, etc.

sub die_usage {
  my $usage =<<EOU;
Usage:
          -c [-method <code>]  -i <image file>
          -d [-method <code>]  -i <code file>
EOU

  die $usage;
}

my $method = 'Gamma';
my $c = 0;
my $d = 0;
my $input_file = '-';
GetOptions('help|usage|?' => sub { die_usage() },
           'c' => \$c,
           'd' => \$d,
           'i=s' => \$input_file,
           'method=s' => \$method);

die_usage if ($c && $d) || (!$c && !$d);

sub predict_med {
  my ($x, $y, $r, $rn) = @_;
  my ($w, $n, $nw);
  $w  = $r ->[$x-1] if $x > 0;
  $nw = $rn->[$x-1] if $x > 0 && $y > 0;
  $n  = $rn->[$x  ] if           $y > 0;

  my $pred;
  if    ( ($x == 0) && ($y == 0) ) { $pred = 0; }    # 0 for first pixel
  elsif ($y == 0)                  { $pred = $w; }   # 1D delta for first row
  elsif ($x == 0)                  { $pred = $n; }   # 1D delta for first col
  else {
    # MED predictor (LOCO-I)
    # a=w, b=n, c=nw, d=ne
    my $maxwn = ($n > $w) ? $n : $w;
    my $minwn = ($n < $w) ? $n : $w;
    if    ($nw >= $maxwn) { $pred = $minwn; }
    elsif ($nw <= $minwn) { $pred = $maxwn; }
    else                  { $pred = $n + $w - $nw; }
  }
  die unless defined $pred;
  return $pred;
}

if ($c) {
  # Use Imager to get the file
  my $image = Imager->new;
  my $idata;
  $image->read(file=>$input_file, data=>\$idata) or die $image->errstr;
  # Image header:
  my ($width, $height, $planes, $mask) = $image->i_img_info;
  # We're only doing grayscale for now
  $image = $image->convert(preset=>'gray') if $planes > 1;

  # Open up stdout as the stream
  my $outfile = 'out.cmp';
  my $stream = Data::BitStream->new( file => $outfile, mode => 'w' );

  my @nvals;
  my @vals;
  foreach my $y (0 .. $height-1) {
    @nvals = @vals;
    # get a scanline worth of pixel values
    @vals = map { ($_->rgba)[0] } $image->getscanline(y=>$y, type=>'8bit');
    my @deltas = ();

    foreach my $x (0 .. $width-1) {
      my $g  = $vals[$x];
      die unless defined $g;

      # 1) Predict this pixel.
      my $predict = predict_med($x, $y, \@vals, \@nvals);

      # 2) encode
      my $delta = $g - $predict;
      my $abs = ($delta >= 0)  ?  2*$delta  :  -2*$delta-1;
#print "[$y,$x] $g => $predict + $delta => $abs\n";
      push @deltas, $abs;
    }
    $stream->code_put($method, @deltas);
  }
  $stream->write_close;
  my $origsize = $width * $height;
  my $compsize = int( ($stream->len + 7) / 8);
  printf "origsize: %d   %s compressed size: %d   ratio %.1fx\n",
         $origsize, $method, $compsize, $origsize / $compsize;
}

if ($d) {
  my $stream = Data::BitStream->new( file => $input_file, mode => 'ro' );

  my ($width, $height, $planes, $mask) = (637, 825, 1, undef);
  my $image = Imager->new(xsize=>$width, ysize=>$height,channels=>$planes);

  my @nvals;
  my @vals;
  foreach my $y (0 .. $height-1) {
    @nvals = @vals;
    @vals = ();
    # get a line worth of absolute deltas
    my @deltas = $stream->code_get($method, $width);
    die "short code read" unless @deltas == $width;
    # convert them to signed deltas
    map { $_ = ( ($_&1) == 0) ? $_ >> 1 : -(($_+1) >> 1); } @deltas;
    foreach my $x (0 .. $width-1) {
      my $predict = predict_med($x, $y, \@vals, \@nvals);
      my $g = $predict + $deltas[$x];
      push @vals, $g;
    }
    # set the scanline
    my @colors = map { Imager::Color->new(gray=>$_); } @vals;
    $image->setscanline(y=>$y, type=>'8bit', pixels=>\@colors);
  }
  my $outfile = 'out.pgm';
  $image->write(file=>$outfile) or die $image->errstr;
}


# reversible RGB/YUV:

if (0) {
  my $rgb;
  my $yuv;
  $yuv = $rgb->convert(matrix=>
      [ [ 0.25,  0.5, 0.25 ],
        [ 1,    -1,   0    ],
        [ 0,    -1,   1    ] ]);

  $rgb = $yuv->convert(matrix=>
      [ [ 1,  0.75, -0.25 ],
        [ 1, -0.25, -0.25 ],
        [ 1, -0.25,  0.75 ] ]);
}
