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
    activeqt => [0, '7a04a93e97390de2d91e89dc907e8240dd5a0c4f'],
    winextras => [0, '5afc77f5347113b607ca0262505f3406e1be5bf4'],
    '3d' => [0, '01aa0a9cb22ce5ed2b7ead03ed9cbeb5f978e897'],
    base => [129, 'e8d9e68d25f4bf305f8b3ca5d678594ee4681baa'],
    charts => [0, '7ce22b0633eb9d1eb59854fee4f2f545e1b842e0'],
    connectivity => [4, 'eeaf42bccd49e8161fbae82d110026d25a5a9a7f'],
    datavis3d => [0, 'd366b0aad8454355acac79eddbab445c1108b1e9'],
    declarative => [26, '5352f113b3c7a5af2ad2741d593c6e6a758eb93e'],
    gamepad => [0, 'f90bd729eb70d4a0770efed3f9bb1b6dbe67d37c'],
    graphicaleffects => [0, '500ae59f809877e0ada9a68601564882f2733145'],
    imageformats => [9, '5aa33ec870977863c400103db94da452edbaf414'],
    location => [4, '664701dc3acfca37500bc84ba03eed4953b684e9'],
    lottie => [0, 'f65b6a268832fc86e1263a6597f2e369aefecd19'],
    multimedia => [3, '78d05cfcec57a9e890cb5ddbea604f194e04315d'],
    networkauth => [0, 'a0f23c6a1f11bd7c6a8e4fd34f10bdb0a35789fa'],
    purchasing => [0, 'a3e675872e4b323f89b94b90b66caa945b576b2e'],
    quick3d => [1, '353f50a9851518eb637181c00302cd354e0ae98b'],
    quickcontrols => [0, '0ea7cfdfbfa72d467fe542cc48ab3206c177a387'],
    quickcontrols2 => [6, '0472a07a8f39587052216d85a7ed235c531eba2c'],
    quicktimeline => [0, '4956b556ccb021e4691f314ab907ea2ebb1ca8a6'],
    remoteobjects => [0, 'd10e7673218fa2b00191a82ad20cd3304a711fa6'],
    scxml => [0, '7f276be586be79d41213a8dd05ef31144313d440'],
    sensors => [0, '45c04582b15a9bb4be01ae99aa7fda1bbba7d0df'],
    serialbus => [0, 'b3081c36baee48b43b6285b4811dc6da451e2390'],
    serialport => [0, 'af58a4c62415fbfd997c43422acf93e2e6ab5155'],
    speech => [1, '75142c77cda8ef3a5c1cae69863e963797c667b5'],
    svg => [8, '37b2c764fb599c96fc415049208e871c729217c8'],
    tools => [3, '9f7af2d08eea7c2a2a2bfe7e6a9b73d1b99f5123'],
    translations => [0, 'a680686754d84b91d4cc4252a2fb8af0c58f5f49'],
    virtualkeyboard => [0, '72373522141dd3206183eb5fa56ae1c36a6d4c2b'],
    wayland => [51, 'aabaa4efd1d284f07c3cb5b8a7d62a9143701bc4'],
    webchannel => [3, '74c0625337c8a8de0a465878c7e7d238e8d979ed'],
    webglplugin => [0, '13202e8a8c0c6d39026344b5a19a0148592160bc'],
    websockets => [2, '89fbe461e7091ae6a4689b7791293a06c9167776'],
    webview => [0, '7e941648610ff4033ae8f9709077edd0595364f0'],
    x11extras => [0, '74f81f0bfe17e5aabcebafcb0cf36f739133554c'],
    xmlpatterns => [0, '0c1dcfe344c03d48d753aeb58f139bc990f2611c'],
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
