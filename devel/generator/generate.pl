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
my @cfg_0_variant_suffixes = (qw(static static-compat));
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
    my $quote  = $prefix =~ qr/^(mingw-w64|android)/ ? "'" : '';
    return join(' ', map { "${quote}${prefix}${package_prefix}-${_}${suffix}${quote}" } @d);
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
    my $prefix     = $controller->stash('install_prefix');
    my $extension  = $controller->stash('library_extension');
    return join(';', map {
        my $library_name = $_;
        $library_name = $1 if $library_name =~ qr/\w*-l(.*)\w*/;
        "$prefix/lib/lib$library_name.$extension";
    } @_);
});

# define revisions of Qt modules from KDE fork
my %kde_fork_revisions = (
    # module => [rev, 'commit on KDE fork', 'version bump to be reverted'],
    '3d' => [17, '5fd3906445ac95bf1cca6e7a7e0aeb6e3bcf5016'],
    activeqt => [0, '065ae50f6bf947f11b7bcaa3199df99a83667574'],
    base => [135, 'e0a15c11b853954d4189b2e30aa2450184de0987'],
    charts => [0, '16c2a8821135bf89369c4e3c5a1bdff8b05ffdb5'],
    connectivity => [4, '25720ab6004cf37ae54ad85d22f87f5fc9e6e72e'],
    datavis3d => [0, '5f8e2a037d5201c902149c828d102b71e90257e2'],
    declarative => [17, '51efb2ed2f071beda188270a23ac450fe4b318f7'],
    gamepad => [0, '8526b210146a2d030ae2f55ad44261befea4a087'],
    graphicaleffects => [0, '4c6ec38635aa22cf0854df8e710733c529f4ec02'],
    imageformats => [0, '8c5bcabbf6a2e27539c2ad689fd69f2406d5cf5c'],
    location => [2, 'db3b6bc6afed6477e6ab2d8465e41efee30fb6d5'],
    lottie => [0, 'ccba2b00bd7f10558edb8664d6b9a95e9fafe6ac'],
    multimedia => [0, 'dc0ee181d4c56ff66c989bd3292dad7cc35e234b'],
    networkauth => [0, '2b0c9499e4000858138802e8f5aa28aa2ebe14c0'],
    purchasing => [0, '397c721847059b998d3b345149a3f6113579d7fe'],
    quick3d => [2, 'd52bfdf7d967419a61c2a4492163626096838a99'],
    quickcontrols => [0, 'd405bf6a29bc9d6da6e3dcefbd1b88f5ed70fb1b'],
    quickcontrols2 => [4, '0d3d39e821ea7634c174a29910c18d7101bce6f7'],
    quicktimeline => [0, '2ce816fa5822bcc1c47678447405b2e5dc1312c1'],
    remoteobjects => [0, '809412e1cc2151c21f843796ef67705600f6aafb'],
    scxml => [0, 'dcbd73cf3e8a07dbfa249d7db2257caafa83781b'],
    sensors => [0, '1ab8d6c7257f9ec060739b648704be1cf1c16b05'],
    serialbus => [0, 'e34053fbda8d687e3dc294fbd5e3a88bf94a7a66'],
    serialport => [0, '191e67e428522a0e2e1e8d2f3440607a9760d441'],
    speech => [1, 'c8a1dadc46ccdbeaef45aa805a9dc98d4b3220bd'],
    svg => [10, '23b8cf7d833c335d7735855570c05e9e0893a9b7'],
    tools => [0, '53ee43a51b5a3de2877dafffc78e71ff55926708'],
    translations => [2, '527dcd684e8d5c645870c854b86df77edeedbc22'],
    virtualkeyboard => [3, 'e8ae4757dd32e8dbf69a7c57f2bc5c1e238416db'],
    wayland => [38, '36659e6130ed3fc2b3f0c91423408ef5ecb7b991'],
    webchannel => [3, '8c842152da613f941892481d62267c73c4a4f006'],
    webglplugin => [0, 'df60c61e640dc4fb6be0d9565a4ab08aee054f93'],
    websockets => [3, '6a4991250793cd38efa5e8db858cd49c82439130'],
    webview => [0, '826d2a33929c69807917536d48b7861e7682001e'],
    winextras => [0, '96cfbd36ad9979ff1974cf137b68b9ae101022c3'],
    x11extras => [0, '51b0a5a2e3e35f4cb17da1e7cb4babef6294bfb4'],
    xmlpatterns => [0, 'dfcae10dec8c1c2c544ad0cd303cea113b0af51d'],
);
# $rev := git rev-list --count v5.15.2..$commit_on_kde_fork

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

    my $kde_fork_revision;
    if ($qt_major_version && $qt_major_version eq '5' && $qt_module) {
        $kde_fork_revision = $kde_fork_revisions{$qt_module};
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
        my $is_mingw            = $package_name_prefix eq 'mingw-w64-';
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
                    kde_fork_revision => $kde_fork_revision,
                    static_variant => $is_static_variant,
                    static_suffix => $is_static_variant ? '-static' : '',
                    static_deps => undef,
                    static_makedeps => undef,
                    is_mingw => $is_mingw,
                    library_extension => $is_static_variant ? 'a' : ($is_mingw ? 'dll.a' : 'so'),
                    install_prefix => $is_mingw ? '/usr/$_arch' : '/usr',
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
