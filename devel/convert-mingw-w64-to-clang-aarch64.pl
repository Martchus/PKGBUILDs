#!/usr/bin/perl

use Mojo::Base -strict, -signatures;
use Mojo::File qw(path);

die "no input file specified\n" unless defined(my $input_path = $ARGV[0]);
die "no output file specified\n" unless defined(my $output_path = $ARGV[1]);

say "converting \"$input_path\" to \"$output_path\"";

my $pkgbuild = path($input_path)->slurp('UTF-8');

$pkgbuild =~ s/mingw-w64-/mingw-w64-clang-aarch64/g;
$pkgbuild =~ s/32:i686-w64-mingw32//g;

path($output_path)->spew($pkgbuild, 'UTF-8');
