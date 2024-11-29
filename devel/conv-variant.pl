#!/usr/bin/perl

use Mojo::Base -strict, -signatures;

use File::Copy::Recursive 'dircopy';
use Mojo::File 'path';
use Mojo::Log;

my $from = shift @ARGV or die "Variant to convert from needs to be specified as first argument\n";
my $to = shift @ARGV or die "Variant to convert to needs to be specified as second argument\n";

my $no_url = sub ($line) { index($line, 'http') < 0 && index($line, '$srcdir') < 0 };
my $no_cond = sub ($line) { $line !~ m/if\s+(\[|test)/ };

my %patterns = (
    'mingw-w64' => {'mingw-w64-clang-aarch64' => [
        {re => '(mingw-w64-)', repl => 'mingw-w64-clang-aarch64-', line_cond => $no_url},
        {re => '\(mingw-w64\)', repl => '(mingw-w64-clang-aarch64)'},
        {re => 'mingw-w64-clang-aarch64-environment', repl => 'mingw-w64-clang-environment'},
        {re => '(["\']*)(mingw-w64-clang-aarch64-(gcc|cairo))(["\']*\s?)', repl => ''},
        {re => '32:i686-w64-mingw32[\s\w\-]*', repl => 'aarch64-w64-mingw32'},
        {re => '64:x86_64-w64-mingw32[\s\w\-]*', repl => 'aarch64-w64-mingw32'},
        {re => '(i686-w64-mingw32[\s\w\-]*)', repl => 'aarch64-w64-mingw32', line_cond => $no_cond},
        {re => '(x86_64-w64-mingw32[\s\w\-]*)', repl => 'aarch64-w64-mingw32', line_cond => $no_cond},
        {re => '(aarch64-w64-mingw32[\s\w\-\'\"]*aarch64-w64-mingw32)', repl => 'aarch64-w64-mingw32'},
        {re => '\$\{?_arch\}?-strip', repl => '$STRIP'},
        {re => '\$\{?_arch\}?-ranlib', repl => '$RANLIB'},
        {se => 'build() {', append => "\n  export USE_COMPILER_WRAPPERS=1", cond => 'mingw-w64-clang-aarch64-configure'},
        {se => 'package() {', append => "\n  export USE_COMPILER_WRAPPERS=1", cond => 'mingw-w64-clang-aarch64-configure'},
        {se => 'for _arch in ${_architectures}; do', append => "\n    source mingw-clang-env \$_arch"},
        {se => 'for _arch in "${_architectures[@]}"; do', append => "\n    source mingw-clang-env \$_arch"},
        {re => '.*source mingw-env.*', repl => ''},
        {re => 'install-mingw-w64-clang-aarch64-strip', repl => 'install-mingw-w64-strip'},
    ]}
);

# allow conversion from mingw-w64-qt6 and *-static to mingw-w64-clang-aarch64-qt6 and *-static as well
my $from_mingw = $patterns{'mingw-w64-qt6'} = $patterns{'mingw-w64-static'} = $patterns{'mingw-w64'};
my $from_mingw_to_clang_aarch64 = $from_mingw->{'mingw-w64-clang-aarch64'};
$from_mingw->{'mingw-w64-clang-aarch64-qt6'} = $from_mingw_to_clang_aarch64;
$from_mingw->{'mingw-w64-clang-aarch64-static'} = $from_mingw_to_clang_aarch64;

my $from_patterns = $patterns{$from} // {};
my $to_patterns = $from_patterns->{$to};
my $force = $ENV{FORCE_VARIANT_CONVERSION} // 0;
die "Conversion from $from to $to not defined\n" unless $to_patterns;

my $log = Mojo::Log->new;
my $has_error;

sub handle_package ($src_path, $dst_path, $always_copy = 0) {
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
            elsif (!$always_copy && -e $dst_file) {
                $log->info("Keeping existing file $dst_file as it is not a symlink");
                next;
            }
            if ($always_copy) {
                if (-d $src_file) {
                    dircopy($src_file, $dst_file) or die "Unable to copy $dst_file: $!\n";
                }
                else {
                    $src_file->copy_to($dst_file);
                }
            }
            else {
                symlink("../$from/$src_basename", $dst_file) or die "Unable to create symlink at $dst_file: $!\n";
            }
            $log->info("Linked $src_file to $dst_file");
            next;
        }
        my $pkgbuild = $src_file->slurp;
        for my $pattern (@$to_patterns) {
            my $cond = $pattern->{cond};
            pos($pkgbuild) = 0;
            next if defined $cond && $pkgbuild !~ m/$cond/g;
            my $re = $pattern->{re};
            my $se = $pattern->{se};
            if (defined(my $repl = $pattern->{repl})) {
                if (defined(my $line_cond = $pattern->{line_cond})) {
                    # go through PKGBUILD match-by-match and check additional condition on the line containing match before doing replacement
                    my $pos = 0;
                    while ($pkgbuild =~ m/$re/g) {
                        next unless my $match = $1;
                        my $match_length = length($match);
                        my $match_start = pos($pkgbuild) - $match_length;
                        my $match_line_start = $match_start;
                        $match_line_start -= 1 while (substr($pkgbuild, $match_line_start, 1) ne "\n" && $match_line_start > 1);
                        my $match_line_end = index($pkgbuild, "\n", $match_start);
                        my $match_line = substr($pkgbuild, $match_line_start, $match_line_end - $match_line_start);
                        if ($line_cond->($match_line)) {
                            my $after_repl = $match_start + length($repl);
                            substr($pkgbuild, $match_start, $match_length) = $repl;
                            pos($pkgbuild) = $after_repl;
                        }
                        $pos = pos($pkgbuild);
                    }
                }
                else {
                    # replace all matches of the specified regex in one go
                    $pkgbuild =~ s/$re/$repl/g;
                }
            }
            elsif (defined(my $append = $pattern->{append})) {
                # in append mode we simply search for the occurrence of a substring and insert additional content after it
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
        handle_package($src_path, $dst_path, 1);
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
