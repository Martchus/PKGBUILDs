#!/usr/bin/perl

use Mojo::File 'path';
use Mojo::Log;

use warnings;
use strict;
use utf8;

my $from = shift @ARGV or die "Variant to convert from needs to be specified as first argument\n";
my $to = shift @ARGV or die "Variant to convert to needs to be specified as second argument\n";

my %patterns = (
    'mingw-w64' => {'mingw-w64-clang-aarch64' => [
        {re => 'mingw-w64-',                                 repl => 'mingw-w64-clang-aarch64-'},
        {re => 'mingw-w64-clang-aarch64-environment',        repl => 'mingw-w64-clang-environment'},
        {re => '["\']*mingw-w64-clang-aarch64-gcc["\']*\s?', repl => ''},
        {re => 'i686-w64-mingw32[\s\w\-]*',                  repl => 'aarch64-w64-mingw32'},
        {re => 'x86_64-w64-mingw32[\s\w\-]*',                repl => 'aarch64-w64-mingw32'},
    ]}
);

my $from_patterns = $patterns{$from} // {};
my $to_patterns = $from_patterns->{$to};
my $force = $ENV{FORCE_VARIANT_CONVERSION} // 0;
die "Conversion from $from to $to not defined\n" unless $to_patterns;

my $log = Mojo::Log->new;
my $has_error;

for my $package (@ARGV) {
    my $src_path = path($package, $from);
    my $dst_path = path($package, $to);
    if (!-f $src_path->child('PKGBUILD')) {
        $log->error("Package $package does not exist under $src_path");
        $has_error = 1;
        next;
    }
    if (-f $dst_path->child('PKGBUILD') && !$force) {
        $log->info("Package $package exist under $dst_path, skipping");
        next;
    }
    $log->info("Converting $src_path to $dst_path");
    $dst_path->make_path;
    for my $src_file (@{$src_path->list({dir => 1})}) {
        my $src_basename = $src_file->basename;
        my $dst_file = $dst_path->child($src_basename);
        if ($src_basename ne 'PKGBUILD') {
            if (-l $dst_file) {
                unlink($dst_file) or die "Unable to unlink $dst_file: $!\n";
            }
            elsif (-e $dst_file) {
                $log->info("Keeping existing file $dst_file as it is not a symlink");
                next;
            }
            symlink("../$from/$src_basename", $dst_file) or die "Unable to create symlink at $dst_file: $!\n";
            $log->info("Linked $src_file to $dst_file");
            next;
        }
        my $pkgbuild = $src_file->slurp;
        $pkgbuild =~ s/$_->{re}/$_->{repl}/g for @$to_patterns;
        $dst_file->spew($pkgbuild);
        $log->info("Converted $src_file to $dst_file");
    }
}

exit($has_error ? 1 : 0);
