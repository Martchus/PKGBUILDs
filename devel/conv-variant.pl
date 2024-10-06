#!/usr/bin/perl

use Mojo::Base -strict, -signatures;
use Mojo::File 'path';
use Mojo::Log;

my $from = shift @ARGV or die "Variant to convert from needs to be specified as first argument\n";
my $to = shift @ARGV or die "Variant to convert to needs to be specified as second argument\n";

my %patterns = (
    'mingw-w64' => {'mingw-w64-clang-aarch64' => [
        {re => 'mingw-w64-', repl => 'mingw-w64-clang-aarch64-'},
        {re => '\(mingw-w64\)', repl => '(mingw-w64-clang-aarch64)'},
        {re => 'mingw-w64-clang-aarch64-environment',        repl => 'mingw-w64-clang-environment'},
        {re => '(["\']*)(mingw-w64-clang-aarch64-gcc)(["\']*\s?)', repl => ''},
        {re => '32:i686-w64-mingw32[\s\w\-]*', repl => 'aarch64-w64-mingw32'},
        {re => '64:x86_64-w64-mingw32[\s\w\-]*', repl => 'aarch64-w64-mingw32'},
        {re => 'i686-w64-mingw32[\s\w\-]*', repl => 'aarch64-w64-mingw32'},
        {re => 'x86_64-w64-mingw32[\s\w\-]*', repl => 'aarch64-w64-mingw32'},
        {re => 'aarch64-w64-mingw32[\s\w\-\'\"]*aarch64-w64-mingw32', repl => 'aarch64-w64-mingw32'},
        {re => '\$\{_arch\}-strip', repl => '$STRIP'},
        {se => 'build() {', append => "\n  export USE_COMPILER_WRAPPERS=1", cond => 'mingw-w64-clang-aarch64-configure'},
        {se => 'package() {', append => "\n  export USE_COMPILER_WRAPPERS=1", cond => 'mingw-w64-clang-aarch64-configure'},
        {se => 'for _arch in ${_architectures}; do', append => "\n    source mingw-clang-env \$_arch"},
    ]}
);

my $from_patterns = $patterns{$from} // {};
my $to_patterns = $from_patterns->{$to};
my $force = $ENV{FORCE_VARIANT_CONVERSION} // 0;
die "Conversion from $from to $to not defined\n" unless $to_patterns;

my $log = Mojo::Log->new;
my $has_error;

sub handle_package ($src_path, $dst_path) {
    $log->info("Converting $src_path to $dst_path");
    $dst_path->make_path;
    for my $src_file (@{$src_path->list({dir => 1})}) {
        my $src_basename = $src_file->basename;
        my $dst_file = $dst_path->child($src_basename);
        if ($src_basename ne 'PKGBUILD') {
            next if $src_basename =~ m/\.bak$/;
            if (-l $dst_file) {
                unlink($dst_file) or die "Unable to unlink $dst_file: $!\n";
            }
            elsif (-e $dst_file) {
                $log->info("Keeping existing file $dst_file as it is not a symlink");
                return;
            }
            symlink("../$from/$src_basename", $dst_file) or die "Unable to create symlink at $dst_file: $!\n";
            $log->info("Linked $src_file to $dst_file");
            return;
        }
        my $pkgbuild = $src_file->slurp;
        for my $pattern (@$to_patterns) {
            my $cond = $pattern->{cond};
            next if defined $cond && index($pkgbuild, $cond) < 0;
            my $re = $pattern->{re};
            my $se = $pattern->{se};
            if (defined(my $repl = $pattern->{repl})) {
                $pkgbuild =~ s/$re/$repl/g;
            }
            elsif (defined(my $append = $pattern->{append})) {
                my $position = 0;
                my $se_len = length($se);
                while (($position = index($pkgbuild, $se, $position)) >= 0) {
                    substr($pkgbuild, $position += $se_len, 0) = $append;
                }
            }
        }
        $dst_file->spew($pkgbuild);
        $log->info("Converted $src_file to $dst_file");
    }
}

if (scalar @ARGV == 2 && ($ARGV[0] =~ m/\// || $ARGV[1] =~ m/\//)) {
    my $src_path = path($ARGV[0]);
    my $dst_path = path($ARGV[1]);
    if (-f $src_path->child('PKGBUILD') && -d $dst_path && ($force || !-f $dst_path->child('PKGBUILD'))) {
        handle_package($src_path, $dst_path);
    }
    else {
        $log->error("Unable to find source and/or destination paths.");
        $has_error = 1;
    }
}
else {
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
        handle_package($src_path, $dst_path);
    }
}

exit($has_error ? 1 : 0);
