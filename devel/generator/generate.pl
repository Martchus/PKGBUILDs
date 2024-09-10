#!/usr/bin/perl

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
    my $quote  = $prefix =~ qr/^(mingw-w64|android|wasm)/ ? "'" : '';
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
    activeqt => [0, '8f8e9fcc03f506cf27b0bb090c5120eaa15c6e19'],
    winextras => [0, 'e1773a917239c5b548ebd9e2ab34a687ffb949e4'],
    '3d' => [0, '84b2eae328fdff5d633af0a9563272c93f6ec074'],
    base => [127, 'ab13e81917207959785ad0185a3a9974e552a7f5'],
    charts => [0, '0c97aae7dc242ac0710e09397672ad878761157a'],
    connectivity => [3, 'f2a9c5d1235d88cc26f2cfa348a037b65e31a5ae'],
    datavis3d => [0, 'e5c03e4431eed6c4654c20fb2d2a20485cff522d'],
    declarative => [25, '310c124dac82d711ab15309a9cb0b9d95db9ea8f'],
    gamepad => [0, 'e9109dadba5c8f2419af67139106b4c30f90332e'],
    graphicaleffects => [0, '4d3d395d14d4a956ac5b30afa859321c1e1934e4'],
    imageformats => [4, '9f658c2093e81d1dc3333e594cc1aa4b0990e221'],
    location => [7, 'e0a477d04f35495ba6eeda8578d1311dba623270'],
    lottie => [0, 'bdbd77ef5529b894699fe8d01642e75230e59f24'],
    multimedia => [2, '85fe63b98703ced6c5568c52af77b50e6ddf1edc'],
    networkauth => [1, '17d6ed940cea4ead62f4055184d4fc69bf06b789'],
    purchasing => [0, '6922c0e403e94ac9c2336706bc3df1e2da217a1f'],
    quick3d => [1, '880d7aa04f3cc331c9bc7ba4ca71d7091480ea6d'],
    quickcontrols => [0, 'fe98f874f89abe9b96edadb812cfa9b1488679f0'],
    quickcontrols2 => [5, 'd0537c14e71d0959f96592b20103033b128f9c0b'],
    quicktimeline => [0, 'a0a95b50f2477823f9400b07e76e516555f16dc0'],
    remoteobjects => [0, '289bbabdff28b4362351f3d91abf75130c9cf666'],
    scxml => [0, '02e1e963ec9492bb1620b3ac3fc6ffc2ff280778'],
    sensors => [0, 'b97c60bee7505eb3901579abc4751f35ba7b303e'],
    serialbus => [0, '77dae896b13e36969fefdfa25d711e455d58597b'],
    serialport => [0, 'aa2ffdbd7295db9e5814070d1432a0b77c59cfce'],
    speech => [1, '71574a57103f0da64ce5e4c0ac6d70141496d5e8'],
    svg => [5, '26fdcaff0d3d6bf6f5c847e833006577a6e8ba7d'],
    tools => [3, '0378d3e541f40bc9c5433eac70d3949ddff9cfc4'],
    translations => [0, '07ae7ea7c94225e73c8eddc9f3f89edc863e83e0'],
    virtualkeyboard => [0, 'e62c1219caef25182ba85383834be04eefce12bf'],
    wayland => [59, '6b1ba1cd0e1389d13e59b94e65da8f20a89ba03f'],
    webchannel => [3, 'ad85920e02049bf7ba06366046498e8366a98e8e'],
    webglplugin => [0, '0d29f1cd46331caf1b5169eb037d573680454348'],
    websockets => [2, '0231c7c3a17c0320601e7766e7e701db5b9eb0dc'],
    webview => [0, '70030514bdaf993517556209503075db15bd1c61'],
    x11extras => [0, 'ff2cc0065a3504e6043b47b1b4601fcdce62eefb'],
    xmlpatterns => [0, '330c47bab8333d6dc7d4ab838afb81f29b6a32d0'],
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
    $output_file->spew($output, 'UTF-8');
}
