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
    # module         => [rev, 'commit on KDE fork',                       'version bump to be reverted'             ],
    '3d'             => [18,  '6d926ec2739f2289c6b0bbfbc325700046e1ceee',                                           ],
    activeqt         => [0,   '2c53a16f431bbb950bfca8ac32ddabf217a0bf04',                                           ],
    base             => [145, 'cfa044e74c4f3be46fe2f177d022af3321766b1f',                                           ],
    charts           => [0,   'f13988aa1ad9de5d92e7b0ba4d0d947dd019d759',                                           ],
    connectivity     => [0,   '8a377440b37f5633156a8e40c9f0dce5f4d5a665',                                           ],
    connnectivity    => [5,   '8a377440b37f5633156a8e40c9f0dce5f4d5a665',                                           ],
    datavis3d        => [0,   '19af9584f7b80928ee49950c573c770af68c9519',                                           ],
    declarative      => [20,  '02105099301450c890e1caba977ef44efdc43da7',                                           ],
    gamepad          => [0,   '6b7a6303439f83147680723f4d8142d676cdb928',                                           ],
    graphicaleffects => [0,   '379577925766385991f413a2b0d0d46831381ffa',                                           ],
    imageformats     => [0,   '90038c936763645610fe1e5f05cfc025e4d98631',                                           ],
    location         => [0,   '1bf01b84e30aab2b87a19184ce42160e6c92d8b1',                                           ],
    lottie           => [0,   'fca3f80f0ce389271e5bd9af864ce56a313d359a',                                           ],
    multimedia       => [0,   'fa6c3d653682f9fd331d859c7196a291a8a4d8d5',                                           ],
    networkauth      => [0,   '958db00a2064f77b354b573102ca2c2b2e07529c',                                           ],
    purchasing       => [0,   '255b9e16f286003bbfaff9d48e4548fb0cb3b398',                                           ],
    quick3d          => [2,   '1ede2ac20170357b3e8d7d9810e5474e08170827',                                           ],
    quickcontrols    => [0,   'd054de15b3c9ead0f96655ddfb1a6381ed7a0e2b',                                           ],
    quickcontrols2   => [4,   '26bd7f5414dc592ab5277e2bb4ad0199faa889de',                                           ],
    quicktimeline    => [0,   '98b1ff53458887061b4bcc183efcce899f432394',                                           ],
    remoteobjects    => [0,   '581475dfeb44c8b51c0be86e0f2f57df7d117a80',                                           ],
    scxml            => [0,   '50d2da3965ed8e85f3f5f5760393c42b12d34a9f',                                           ],
    sensors          => [0,   '975ba788d3d0ee87aa08bb5301cd33dcbf00521b',                                           ],
    serialbus        => [0,   '22b3cad193232ab379a0c9e16989a7db1fdc9234',                                           ],
    serialport       => [0,   'f95e2411d7c978def87846ea7cedf3dc5fd7c8b8',                                           ],
    speech           => [1,   '08b27c29aadc0cc0303cca97c9a3baa2a690dfe4',                                           ],
    svg              => [12,  '2f42157cabbd1db6249ccb1d14e6eede80451e0c',                                           ],
    tools            => [1,   'a3e5b2eb8ef5982bc1fffb390ebcd141be1deee4',                                           ],
    translations     => [2,   'a6d5e7f84a57394db4c8b069f81c56cfeb802e19',                                           ],
    virtualkeyboard  => [3,   'bb40dee811333929dd467a480dce24ab7af84ef9',                                           ],
    wayland          => [40,  '118674630cdb5933e66a8b4415afe7c716ad4662',                                           ],
    webchannel       => [3,   '611016a49f3a9ba7b58bef29bc295323e06373ae',                                           ],
    webglplugin      => [0,   '4318ad91c2a8bea3a0aaaa64aaf49d3b997e50a1',                                           ],
    websockets       => [3,   '7196d2cc34adf9f45b50a9488f4ff95b36092993',                                           ],
    winextras        => [0,   '051202df9c553d7c0a384f07bd67fde98f3b02c4',                                           ],
    xmlpatterns      => [0,   'af4958af9d628d6124e64abd9743abce42f15a6f',                                           ],
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
