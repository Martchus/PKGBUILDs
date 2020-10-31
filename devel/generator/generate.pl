#!/usr/bin/perl

use Encode 'encode';
use FindBin;
use Mojolicious;
use Mojo::File 'path';
use Mojo::Log;
use Mojo::Util;

use warnings;
use strict;
use utf8;

my @vcs_0_variant_suffixes = (qw(git svn hg));
my @cfg_0_variant_suffixes = (qw(static));
my @cfg_1_variant_suffixes = (qw(doc test cli angle dynamic opengl noopengl));
my @variant_suffixes       = (\@vcs_0_variant_suffixes, \@cfg_0_variant_suffixes, \@cfg_1_variant_suffixes);

sub is_outdated {
    my ($source_path, $target_path) = @_;

    my $source_last_modified = (stat($source_path))[9];
    my $target_last_modified = (stat($target_path))[9];
    return !defined $target_last_modified || $source_last_modified > $target_last_modified;
}

my $log = Mojo::Log->new;
my $mojolicious = Mojolicious->new;
my $renderer = $mojolicious->renderer;
my $pkgbuilds_dir = path($FindBin::Bin, '..', '..')->realpath;
my @template_paths = ("$FindBin::Bin/templates", $pkgbuilds_dir);

$log->level($ENV{LOG_LEVEL} // 'info');
$mojolicious->log($log);
$renderer->paths(\@template_paths);
$log->debug("Template paths:\n" . join("\n", @template_paths));

my $filter_regex      = $ARGV[0];
my $install_directory = $ARGV[1] // $pkgbuilds_dir;
unless (-d $install_directory) {
    $log->error("Output directory '$install_directory' does not exist.");
    exit(-1);
}

# add helper to render Qt dependencies
sub _render_deps {
    my ($package_prefix, $controller, @d) = @_;
    my $prefix = $controller->stash('package_name_prefix');
    my $suffix = $controller->stash('package_name_suffix');
    return join(' ', map { "'${prefix}${package_prefix}-${_}${suffix}'" } @d);
}
sub _render_optdeps {
    my ($package_prefix, $controller, %d) = @_;
    my $prefix = $controller->stash('package_name_prefix');
    my $suffix = $controller->stash('package_name_suffix');
    return join(' ', map { "'${prefix}${package_prefix}-${_}${suffix}: $d{$_}'" } sort keys %d);
}
for my $qt_version (qw(qt5 qt6)) {
    $mojolicious->helper("${qt_version}deps" => sub { _render_deps($qt_version, @_) });
    $mojolicious->helper("${qt_version}optdeps" => sub { _render_optdeps($qt_version, @_) });
}

# add helper to expand pkg-config style libraries into full paths for use with CMake
# example: "-lfoo -lbar" => "/usr/lib/foo.a;/usr/lib/bar.a"
$mojolicious->helper(expand_libs => sub {
    my $controller = shift;
    my $is_static  = $controller->stash('static_variant');
    my $is_mingw   = $controller->stash('package_name_prefix') eq 'mingw-w64-';
    my $prefix     = $is_mingw  ? '/usr/$_arch' : '/usr';
    my $extension  = $is_static ? 'a' : ($is_mingw ? 'dll.a' : 'so');
    return join(';', map {
        my $library_name = $_;
        $library_name = $1 if $library_name =~ qr/\w*-l(.*)\w*/;
        "$prefix/lib/lib$library_name.$extension";
    } @_);
});

# find templates; populate "pages" array
my @pages;
my $template_file_name = 'PKGBUILD.sh.ep';
my $top_level_dirs = $pkgbuilds_dir->list({dir => 1});
for my $top_level_dir (@$top_level_dirs) {
    next unless -d $top_level_dir;
    next unless $top_level_dir ne 'devel';

    my $default_package_name = $top_level_dir->basename;
    my ($qt_module, $qt_major_version);
    if ($default_package_name =~ qr/qt(5|6)-(.*)/) {
        $qt_major_version = $1;
        $qt_module        = $2;
    }

    my $variant_dirs = $top_level_dir->list({dir => 1});
    for my $variant_dir (@$variant_dirs) {
        next unless -d $variant_dir;

        my $variant = $variant_dir->basename;
        my $template_file = $variant_dir->child($template_file_name);
        if (!-f $template_file) {
            # print warning; all additional Qt repos for mingw-w64 should be converted to use templates now
            $log->warn("No template $template_file_name present for Qt module $qt_module and variant $variant")
                if defined $qt_module && index($variant, 'mingw-w64') == 0 && $variant !~ qr/.*-test$/;
            next;
        }

        # determine files
        my $files = $variant_dir->list;
        my $patch_files = $files->grep(qr/.*\.patch/);
        my $qt_module_sha256_file_name = "qt$qt_module-sha256.txt";
        my $qt_module_sha256_file = defined $qt_module
            ? $variant_dir->child($qt_module_sha256_file_name)
            : undef;
        my $qt_module_sha256 = defined $qt_module_sha256_file && -f $qt_module_sha256_file
            ? Mojo::Util::trim($qt_module_sha256_file->slurp)
            : "$qt_module_sha256_file_name missing";

        # determine variant parts
        my $variant_prefix_part = $variant;
        my $variant_suffix_part = '';
        if ($variant) {
            for my $variant_suffixes (@variant_suffixes) {
                for my $variant_suffix (@$variant_suffixes) {
                    next unless $variant =~ qr/.*-$variant_suffix$/;
                    $variant_prefix_part = substr($variant, 0, length($variant) - length($variant_suffix) - 1);
                    $variant_suffix_part = $variant_suffix_part ? "$variant_suffix-$variant_suffix_part" : $variant_suffix;
                    last;
                }
            }
        }
        my $package_name_prefix = $variant_prefix_part ? "$variant_prefix_part-" : "";
        my $package_name_suffix = $variant_suffix_part ? "-$variant_suffix_part" : "";
        my $is_static_variant   = $variant_suffix_part =~ qr/static/;
        my $has_static_variant  = $is_static_variant || -d "$default_package_name/$variant-static";
        my $package_name        = "$package_name_prefix$default_package_name$package_name_suffix";
        next if defined $filter_regex && $package_name !~ $filter_regex;

        push(@pages, {
                install_path => "$default_package_name/$variant/PKGBUILD",
                template_params => [
                template => "$default_package_name/$variant/PKGBUILD",
                stash_variables => {
                    variant => $variant,
                    variant_prefix_part => $variant_prefix_part,
                    variant_suffix_part => $variant_suffix_part,
                    default_package_name => $default_package_name,
                    package_name_prefix => $package_name_prefix,
                    package_name_suffix => $package_name_suffix,
                    package_name => $package_name,
                    files => $files,
                    patch_files => $patch_files,
                    qt_major_version => $qt_major_version,
                    qt_module => $qt_module,
                    qt_module_sha256 => $qt_module_sha256,
                    static_variant => $is_static_variant,
                    static_deps => undef,
                    static_makedeps => undef,
                    shared_config => !$is_static_variant,
                    static_config => $is_static_variant || !$has_static_variant,
                    no_libraries => 0,
                },
            ]
        });
    }
}

# render "pages"
for my $page (@pages) {
    # process template params
    my $template_params = $page->{template_params};
    my $template_source_path;
    my $template_target_path;
    my $template_stash_variables;
    if (defined $template_params) {
        my ($template_name, $template_args) = (@$template_params % 2 ? shift @$template_params : undef, {@$template_params});
        my $template_format = ($template_args->{format} //= 'sh');
        my $template_handler = $template_args->{handler} // 'ep';
        $template_name             //= $template_args->{template};
        $template_stash_variables    = delete $template_args->{stash_variables};
        $template_source_path        = "$template_name.$template_format.$template_handler";
        $template_target_path        = "$template_name.$template_format";
        $template_params             = $template_args;
        $template_params->{template} = $template_name;
    }

    # determine source path and target path
    my $source_path = $page->{source_path} // $template_source_path;
    if (!$template_params && !$source_path) {
        die 'page needs either template_params or source_path';
    }
    my $output_file = path($install_directory, $page->{install_path} // $template_target_path // $source_path);

    # ensure output directory exists
    $output_file->dirname->make_path unless -f $output_file;

    # skip unless the target is outdated
    # note: Can not skip templates that easy because that would require tracking includes.
    if (!defined $template_params && !is_outdated($source_path, $output_file)) {
        $log->info("Skipping '$source_path' -> '$output_file' (target up-to-date)");
        next;
    }

    # do a simple copy
    if (!defined $template_params) {
        $log->info("Copying '$source_path' -> '$output_file'");
        Mojo::File->new($source_path)->copy_to($output_file);
        next;
    }

    # render template
    $log->info("Rendering '$source_path' -> '$output_file'");
    my $controller = $mojolicious->build_controller;
    $controller->stash($template_stash_variables) if defined $template_stash_variables;
    my $output = $controller->render_to_string(%$template_params);
    $log->debug($output);
    $output_file->spurt(encode('UTF-8', $output));
}
