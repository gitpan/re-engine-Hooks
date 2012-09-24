#!perl

use strict;
use warnings;

use Getopt::Std;

use File::Path;
use File::Copy;
use File::Spec;

use Time::HiRes;

use Module::CoreList;
use version;

use File::Fetch;
use Archive::Extract;

my $has_cpan_perl_releases;
BEGIN {
 local $@;
 if (eval { require CPAN::Perl::Releases; 1 }) {
  print "Will use CPAN::Perl::Releases\n";
  $has_cpan_perl_releases = 1;
 }
}

my %opts;
getopts('ft:m:', \%opts);

my $cpan_mirror = 'cpan.cpantesters.org';
my $target      = 'src';

{
 local $@;
 eval 'setpgrp 0, 0';
}
local $SIG{'INT'} = sub { exit 1 };

{
 package Guard::Path;

 sub new {
  my $class = shift;

  my %args = @_;
  my ($path, $indent, $keep) = @args{qw<path indent keep>};

  die "Path $path already exists" if -e $path;
  File::Path::mkpath($path);

  bless {
   path   => $path,
   indent => $indent || 0,
   keep   => $keep,
  }, $class;
 }

 BEGIN {
  local $@;
  eval "sub $_ { \$_[0]->{$_} }; 1" or die $@ for qw<path indent>;
 }

 sub keep { @_ > 1 ? $_[0]->{keep} = $_[1] : $_[0]->{keep} }

 sub DESTROY {
  my $self = shift;

  return if $self->keep;

  my $path = $self->path;
  return unless -e $path;

  my $indent = $self->indent;
  $indent = ' ' x (2 * $indent);

  print "${indent}Cleaning up path $path... ";
  File::Path::remove_tree($path);
  print "done\n";
 }
}

sub key_version {
 my $num_version = shift;

 my $obj            = version->parse($num_version);
 my $pretty_version = $obj->normal;
 $pretty_version =~ s/^v?//;

 my ($int, $frac) = split /\./, $num_version, 2;

 die 'Wrong fractional part' if length $frac > 6;
 $frac .= '0' x (6 - length $frac);

 "$int$frac" => [ $num_version, $pretty_version ];
}

my %perls = map key_version($_),
             grep "$_" >= '5.010001',
              keys %Module::CoreList::released;

sub fetch_uri {
 my ($uri, $to) = @_;

 my $start = [ Time::HiRes::gettimeofday ];

 my $ff   = File::Fetch->new(uri => $uri);
 my $file = $ff->fetch(to => $to) or die "Could not fetch $uri: " . $ff->error;

 my $elapsed = Time::HiRes::tv_interval($start);

 return $file, $elapsed;
}

sub perl_archive_for {
 my $version = shift;

 my $path;

 if ($has_cpan_perl_releases) {
  my $tarballs = CPAN::Perl::Releases::perl_tarballs($version);

  if (defined $tarballs) {
   $path = $tarballs->{'tar.gz'};
  }
 } else {
  my $uri = "http://search.cpan.org/dist/perl-$version";

  local $_;
  fetch_uri($uri => \$_);

  if (m{id/(([^/])/\2([^/])/\2\3[^/]*/perl-\Q$version\E\.tar\.(?:gz|bz2))}) {
   $path = $1;
  }
 }

 if (defined $path) {
  my ($file) = ($path =~ m{([^/]*)$});
  return "http://$cpan_mirror/authors/id/$path", $file;
 } else {
  die "Could not infer the archive for perl $version";
 }
}

sub bandwidth {
 my ($size, $seconds) = @_;

 my $speed = $size / $seconds;

 my $order = 0;
 while ($speed >= 1024) {
  $speed /= 1024;
  $order++;
 }

 $speed = sprintf '%.02f', $speed;

 my $unit = ('', 'K', 'M', 'G', 'T', 'P')[$order] . 'B/s';

 return $speed, $unit;
}

sub touch {
 my $file = shift;

 open my $fh, '>', $file or die "Can't open $file for writing: $!";
}

File::Path::mkpath($target) unless -e $target;

my $tmp_dir = File::Spec->catdir($target, 'tmp');

sub fetch_source_file {
 my ($file, $version, $dir) = @_;

 my $INDENT = ' ' x 4;

 print "${INDENT}Looking for the full name of the perl archive... ";
 my ($archive_uri, $archive_file) = perl_archive_for($version);
 print "$archive_uri\n";

 if (-e File::Spec->catfile($tmp_dir, $archive_file)) {
  print "${INDENT}$archive_file was already fetched\n";
 } else {
  print "${INDENT}Fetching $archive_uri... ";
  ($archive_file, my $elapsed) = fetch_uri($archive_uri => $tmp_dir);
  my ($speed, $unit) = bandwidth(-s $archive_file, $elapsed);
  print "done at $speed$unit\n";
 }

 my $extract_path = File::Spec->catfile($tmp_dir, "perl-$version");
 if (-e $extract_path) {
  print "${INDENT}$archive_file was already extracted\n";
 } else {
  print "${INDENT}Extracting $archive_file... ";
  my $ae = Archive::Extract->new(archive => $archive_file);
  $ae->extract(to => $tmp_dir)
                        or die "Could not extract $archive_file: " . $ae->error;
  $extract_path = $ae->extract_path;
  print "done\n";
 }

 File::Path::mkpath($dir) unless -e $dir;
 print "${INDENT}Copying $file to $dir... ";
 my $src = File::Spec->catfile($extract_path, $file);
 my $dst = File::Spec->catfile($dir,          $file);
 if (-e $src) {
  File::Copy::copy($src => $dst) or die "Can't copy $src to $dst: $!";
  print "done\n";
  return 1;
 } else {
  touch($dst);
  print "not needed\n";
  return 0;
 }
}

my %patched_chunks;
my %expected_chunks = (
 'regcomp.c' => [
  're_defs',
  'COMP_NODE_HOOK',
  'COMP_BEGIN_HOOK',
  ('COMP_NODE_HOOK') x 3,
 ],
 'regexec.c' => [
  're_defs',
  'EXEC_NODE_HOOK',
 ],
);

sub patch_regcomp {
 my ($line, $file) = @_;

 if ($line =~ /#\s*include\s+"INTERN\.h"/) {
  push @{$patched_chunks{$file}}, 're_defs';
  return "#include \"re_defs.h\"\n";
 } elsif ($line =~ /^(\s*)RExC_rxi\s*=\s*ri\s*;\s*$/) {
  push @{$patched_chunks{$file}}, 'COMP_BEGIN_HOOK';
  return $line, "$1REH_CALL_COMP_BEGIN_HOOK(pRExC_state->rx);\n";
 } elsif ($line =~ /FILL_ADVANCE_NODE(_ARG)?\(\s*([^\s,\)]+)/) {
  my $shift = $1 ? 2 : 1;
  push @{$patched_chunks{$file}}, 'COMP_NODE_HOOK';
  return $line, "    REH_CALL_COMP_NODE_HOOK(pRExC_state->rx, ($2) - $shift);\n"
 } elsif ($line =~ /end node insert/) {
  push @{$patched_chunks{$file}}, 'COMP_NODE_HOOK';
  return $line, "    REH_CALL_COMP_NODE_HOOK(pRExC_state->rx, convert);\n";
 } elsif ($line =~ /&PL_core_reg_engine/) {
  $line =~ s/&PL_core_reg_engine\b/&reh_regexp_engine/g;
  return $line;
 }

 return $line;
}

sub patch_regexec {
 my ($line, $file) = @_;

 if ($line =~ /#\s*include\s+"perl\.h"/) {
  push @{$patched_chunks{$file}}, 're_defs';
  return $line, "#include \"re_defs.h\"\n";
 } elsif ($line =~ /^\s*reenter_switch:\s*$/) {
  push @{$patched_chunks{$file}}, 'EXEC_NODE_HOOK';
  return "\tREH_CALL_EXEC_NODE_HOOK(rex, scan, reginfo, st);\n", $line;
 }

 return $line;
}

my %manglers = (
 'regcomp.c' => \&patch_regcomp,
 'regexec.c' => \&patch_regexec,
);

sub patch_source_file {
 my ($src, $dst) = @_;

 my $file = (File::Spec->splitpath($src))[2];
 if (-d $dst) {
  $dst = File::Spec->catfile($dst, $file);
 }

 my $mangler = $manglers{$file};
 unless ($mangler) {
  File::Copy::copy($src => $dst) or die "Can't copy $src to $dst: $!";
  return 0;
 }

 open my $in,  '<', $src or die "Can't open $src for reading: $!";
 open my $out, '>', $dst or die "Can't open $dst for writing: $!";

 while (defined(my $line = <$in>)) {
  print $out $mangler->($line, $dst);
 }

 my $patched_chunks  = join ' ', @{$patched_chunks{$dst}};
 my $expected_chunks = join ' ', @{$expected_chunks{$file}};
 unless ($patched_chunks eq $expected_chunks) {
  die "File $dst was not properly patched (got \"$patched_chunks\", expected \"$expected_chunks\")\n";
 }

 return 1;
}

for my $tag (sort { $a <=> $b } keys %perls) {
 my ($num_version, $pretty_version) = @{$perls{$tag}};

 my $dir = File::Spec->catdir($target, $tag);

 print "Working on perl $pretty_version\n";

 my $tmp_guard = Guard::Path->new(path => $tmp_dir);

 my $orig_dir = File::Spec->catdir($dir, 'orig');

 my @files = qw<regcomp.c regexec.c>;
 push @files, 'dquote_static.c'  if $num_version >= 5.013_006;
 push @files, 'inline_invlist.c' if $num_version >= 5.017_004;
 for my $file (@files) {
  my $orig_file = File::Spec->catfile($orig_dir, $file);
  if (-e $orig_file) {
   print "  Already have original $file\n";
  } else {
   print "  Need to get original $file\n";
   fetch_source_file($file, $pretty_version => $orig_dir);
  }

  if (-s $orig_file) {
   if (not $opts{f} and -e File::Spec->catfile($dir, $file)) {
    print "  Already have patched $file\n";
   } else {
    print "  Need to patch $file... ";
    my $res = patch_source_file($orig_file => $dir);
    print $res ? "done\n" : "nothing to do\n";
   }
  }
 }
}

{
 print 'Updating MANIFEST... ';

 my @manifest_files;
 if (-e 'MANIFEST') {
  open my $in, '<', 'MANIFEST' or die "Can't open MANIFEST for reading: $!";
  @manifest_files = grep !m{^src/.*\.c$}, <$in>;
 }

 my @source_files = map "$_\n", glob 'src/*/*.c';

 open my $out, '>', 'MANIFEST' or die "Can't open MANIFEST for writing: $!";
 print $out sort @manifest_files, @source_files;

 print "done\n";
}
