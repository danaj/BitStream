package Data::BitStream::Code::BoldiVigna;
BEGIN {
  $Data::BitStream::Code::BoldiVigna::AUTHORITY = 'cpan:DANAJ';
}
BEGIN {
  $Data::BitStream::Code::BoldiVigna::VERSION = '0.01';
}

use Mouse::Role;

requires 'read', 'write', 'put_unary', 'get_unary';

# Boldi-Vigna Zeta codes.

# TODO: cache these
sub _hparam_map {
  my $k = shift;
  my $maxbits = shift;

  my $maxhk = 0;
  $maxhk += $k while ($maxhk+$k) < $maxbits;

  my @hparams;  # stores [s threshold] for each h
  foreach my $h (0 .. $maxhk/$k) {
    my $hk = $h*$k;
    my $interval = (1 << ($hk+$k)) - (1 << $hk) - 1;
    my $z = $interval+1;
    my $s = 1;
    { my $v = $z;  $s++ while ($v >>= 1); } # ceil log2($z)
    my $threshold = (1 << $s) - $z;
    $hparams[$h] = [ $s, $threshold ];
    #print "storing params for h=$h  [ $s, $threshold ]\n";
  }

  return $maxhk, \@hparams;
}

sub put_boldivigna {
  my $self = shift;
  my $k = shift;
  die "k must be >= 1" unless $k >= 1;

  return $self->put_gamma(@_) if $k == 1;

  my ($maxhk, $hparams) = _hparam_map($k, $self->maxbits);

  foreach my $v (@_) {
    die "Value must be >= 0" unless $v >= 0;
    my $val = $v+1;  # TODO encode ~0

    my $hk = 0;
    $hk += $k  while ( ($hk < $maxhk) && ($val >= (1 << ($hk+$k))) );
    my $h = $hk/$k;
    $self->put_unary($h);

    my $x = $val - (1 << $hk);
    # Encode $x using "minimal binary code"
    my ($s, $threshold) = @{$hparams->[$h]};
    #print "using params for h=$h  [ $s, $threshold ]\n";
    if ($x < $threshold) {
      #print "minimal code $x in ", $s-1, " bits\n";
      $self->write($s-1, $x);
    } else {
      #print "minimal code $x => ", $x+$threshold, " in $s bits\n";
      $self->write($s, $x+$threshold);
    }
  }
  1;
}
sub get_boldivigna {
  my $self = shift;
  my $k = shift;
  die "k must be >= 1" unless $k >= 1;

  return $self->get_gamma(@_) if $k == 1;

  my $count = shift;
  if    (!defined $count) { $count = 1;  }
  elsif ($count  < 0)     { $count = ~0; }   # Get everything
  elsif ($count == 0)     { return;      }

  my ($maxhk, $hparams) = _hparam_map($k, $self->maxbits);

  my @vals;
  while ($count-- > 0) {
    my $h = $self->get_unary();
    last unless defined $h;
    my ($s, $threshold) = @{$hparams->[$h]};
    my $val = 1 << $h*$k;

    my $first = $self->read($s-1);
    if ($first >= $threshold) {
      $first = ($first << 1) + $self->read(1) - $threshold;
    }
    $val += $first;
    push @vals, $val-1;
  }
  wantarray ? @vals : $vals[-1];
}
no Mouse;
1;
