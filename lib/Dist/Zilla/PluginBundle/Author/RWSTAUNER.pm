package Dist::Zilla::PluginBundle::Author::RWSTAUNER;
# ABSTRACT: RWSTAUNER's Dist::Zilla config

use strict;
use warnings;
use Moose;
use Dist::Zilla 4.102345;
with 'Dist::Zilla::Role::PluginBundle::Easy';
# Dist::Zilla::Role::DynamicConfig is not necessary: payload is already dynamic

use Dist::Zilla::PluginBundle::Basic (); # use most of the plugins included
use Dist::Zilla::PluginBundle::Git 1.110500 ();
use Dist::Zilla::Plugin::Authority 1.001 ();
use Dist::Zilla::Plugin::Bugtracker ();
#use Dist::Zilla::Plugin::CheckExtraTests ();
use Dist::Zilla::Plugin::CheckChangesHasContent 0.003 ();
use Dist::Zilla::Plugin::CompileTests 1.100740 ();
use Dist::Zilla::Plugin::CPANChangesTests ();
use Dist::Zilla::Plugin::DualBuilders 1.001 (); # only runs tests once
use Dist::Zilla::Plugin::Git::NextVersion ();
use Dist::Zilla::Plugin::GithubMeta 0.10 ();
use Dist::Zilla::Plugin::KwaliteeTests ();
use Dist::Zilla::Plugin::InstallRelease 0.006 ();
#use Dist::Zilla::Plugin::MetaData::BuiltWith (); # FIXME: see comment below
use Dist::Zilla::Plugin::MetaNoIndex 1.101130 ();
use Dist::Zilla::Plugin::MetaProvides::Package 1.11044404 ();
use Dist::Zilla::Plugin::MinimumPerl 0.02 ();
use Dist::Zilla::Plugin::MinimumVersionTests ();
use Dist::Zilla::Plugin::NextRelease ();
use Dist::Zilla::Plugin::PkgVersion ();
use Dist::Zilla::Plugin::PodCoverageTests ();
use Dist::Zilla::Plugin::PodSpellingTests ();
use Dist::Zilla::Plugin::PodSyntaxTests ();
use Dist::Zilla::Plugin::PodWeaver ();
use Dist::Zilla::Plugin::PortabilityTests ();
use Dist::Zilla::Plugin::Prepender 1.100960 ();
use Dist::Zilla::Plugin::Repository 0.16 (); # deprecates github_http
use Dist::Zilla::Plugin::ReportVersions::Tiny 1.01 ();
use Dist::Zilla::Plugin::TaskWeaver 0.101620 ();
use Dist::Zilla::Plugin::Test::Pod::LinkCheck ();
use Dist::Zilla::Plugin::Test::Pod::No404s ();
use Pod::Weaver::PluginBundle::Author::RWSTAUNER ();

# cannot use $self->name for class methods
sub _bundle_name {
	my $class = @_ ? ref $_[0] || $_[0] : __PACKAGE__;
	join('', '@', ($class =~ /^.+::PluginBundle::(.+)$/));
}

# TODO: consider an option for using ReportPhase
sub _default_attributes {
	return {
		auto_prereqs   => [Bool => 1],
		fake_release   => [Bool => $ENV{DZIL_FAKERELEASE}],
		install_command => [Str  => 'cpanm -v -i . -l ~/perl5'],
		is_task        => [Bool => 0],
		releaser       => [Str  => 'UploadToCPAN'],
		skip_plugins   => [Str  => ''],
		skip_prereqs   => [Str  => ''],
		weaver_config  => [Str  => $_[0]->_bundle_name],
		use_git_bundle => [Bool => 1],
	};
}

sub _generate_attribute {
	my ($self, $key) = @_;
	has $key => (
		is      => 'ro',
		isa     => $self->_default_attributes->{$key}[0],
		lazy    => 1,
		default => sub {
			# if it exists in the payload
			exists $_[0]->payload->{$key}
				# use it
				?  $_[0]->payload->{$key}
				# else get it from the defaults (for subclasses)
				:  $_[0]->_default_attributes->{$key}[1];
		}
	);
}

{
	# generate attributes
	__PACKAGE__->_generate_attribute($_)
		for keys %{ __PACKAGE__->_default_attributes };
}

# main
sub configure {
	my ($self) = @_;

	my $skip = $self->skip_plugins;
	$skip &&= qr/$skip/;

	my $dynamic = $self->payload;

	$self->_add_bundled_plugins;
	my $plugins = $self->plugins;

	my $i = -1;
	while( ++$i < @$plugins ){
		my $spec = $plugins->[$i] or next;
		# NOTE: $conf retains its reference (modifications alter $spec)
		my ($name, $class, $conf) = @$spec;

		# ignore the prefix (@Bundle/Name => Name) (DZP::Name => Name)
		(my $alias   = $name ) =~ s/^${\ $self->name }\///;
		(my $moniker = $class) =~ s/^Dist::Zilla::Plugin(?:Bundle):://;

		# exclude any plugins that match 'skip_plugins'
		if( $skip ){
			# match on name (alias) or plugin class
			if( $alias =~ $skip || $class =~ $skip ){
				splice(@$plugins, $i, 1);
				redo;
			}
		}

		# search the dynamic config for anything matching the current plugin
		my $plugin_attr = qr/^(?:$alias|.?$moniker)\W+(\w+)(\W*)$/;
		while( my ($key, $val) = each %$dynamic ){
			# match keys like Plugin::Name:attr and PlugName/attr@
			next unless
				my ($attr, $over) = ($key =~ $plugin_attr);

			# if its already an arrayref
			if( ref(my $current = $conf->{$attr}) eq 'ARRAY' ){
				# overwrite if specified, otherwise append
				$val = $over ? [$val] : [@$current, $val];
			}
			# modify original
			$conf->{$attr} = $val;
		}
	};
}

sub _add_bundled_plugins {
	my ($self) = @_;

	$self->log_fatal("you must not specify both weaver_config and is_task")
		if $self->is_task and $self->weaver_config ne $self->_bundle_name;

	$self->add_plugins(
	
	# provide version
		#'Git::DescribeVersion',
		'Git::NextVersion',

	# gather and prune
		qw(
			GatherDir
			PruneCruft
			ManifestSkip
		),

	# munge files
		[ 'Authority' => { do_metadata => 1 }],
		[
			NextRelease => {
				format => '%v %{yyyy-MM-dd}d'
			}
		],
		'PkgVersion',
		'Prepender',
		( $self->is_task
			?  'TaskWeaver'
			: [ 'PodWeaver' => { config_plugin => $self->weaver_config } ]
		),

	# generated distribution files
		qw(
			License
			Readme
		),
		# @APOCALYPTIC: generate MANIFEST.SKIP ?

	# metadata
		'Bugtracker',
		# won't find git if not in repository root (!-e ".git")
		'Repository',
		# overrides [Repository] if repository is on github
		'GithubMeta',
	);

	$self->add_plugins(
		[ AutoPrereqs => $self->config_slice({ skip_prereqs => 'skip' }) ]
	)
		if $self->auto_prereqs;

	$self->add_plugins(
#		[ 'MetaData::BuiltWith' => { show_uname => 1 } ], # currently DZ::Util::EmulatePhase causes problems
		[
			MetaNoIndex => {
				# could use grep { -d $_ } but that will miss any generated files
				directory => [qw(corpus examples inc share t xt)],
#				'namespace' => [qw(Local t::lib)],
#				'package' => [qw(DB)]
			}
		],
		[ 	# AFTER MetaNoIndex
			'MetaProvides::Package' => {
				meta_noindex => 1
			}
		],

		qw(
			MinimumPerl
			MetaConfig
			MetaYAML
			MetaJSON
		),

		[
			Prereqs => 'TestMoreWithSubtests' => {
				-phase => 'test',
				-type  => 'requires',
				'Test::More' => '0.96'
			}
		],

	# build system
		qw(
			ExtraTests
			ExecDir
			ShareDir
			MakeMaker
			ModuleBuild
			DualBuilders
		),

	# generated t/ tests
		[ CompileTests => { fake_home => 1 } ],
		qw(
			ReportVersions::Tiny
		),

	# generated xt/ tests
		qw(
			CPANChangesTests
			MetaTests
			PodSyntaxTests
			PodCoverageTests
		),
		# Test::Pod::Spelling::CommonMistakes ?
		qw(
			PodSpellingTests
			PortabilityTests
			KwaliteeTests
			MinimumVersionTests
			Test::Pod::LinkCheck
			Test::Pod::No404s
		),
	);

	$self->add_plugins(
	# manifest: must come after all generated files
		'Manifest',

	# before release
			#CheckExtraTests
		qw(
			CheckChangesHasContent
			TestRelease
			ConfirmRelease
		),

	# release
		( $self->fake_release ? 'FakeRelease' : $self->releaser ),
	);

	# TODO: query zilla for phase... if release, announce which releaser we're using

	$self->add_bundle( '@Git' )
		if $self->use_git_bundle;
	
	$self->add_plugins([ InstallRelease =>
		{ install_command => $self->install_command } ])
			if $self->install_command;
}

#	$self->add_bundle('@Git' => {
#		tag_format => '%v',
#		push_to    => [ qw(origin github) ],
#	});

# As of Dist::Zilla 4.102345 pluginbundles don't have log and log_fatal methods
# but hopefully someday they will... so define our own unless they exist.
foreach my $method ( qw(log log_fatal) ){
	unless( __PACKAGE__->can($method) ){
		no strict 'refs';
		*$method = $method =~ /fatal/
			? sub { die($_[1]) }
			: sub { warn("[${\$_[0]->_bundle_name}] $_[1]") };
	}
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=for stopwords PluginBundle PluginBundles DAGOLDEN RJBS dists ini arrayrefs

=for Pod::Coverage configure
log log_fatal

=head1 SYNOPSIS

	# dist.ini

	[@Author::RWSTAUNER]

=head1 DESCRIPTION

This is an Author
L<Dist::Zilla::PluginBundle|Dist::Zilla::Role::PluginBundle::Easy>
that I use for building my dists.

This Bundle was heavily influenced by the bundles of
L<RJBS|Dist::Zilla::PluginBundle::RJBS> and
L<DAGOLDEN|Dist::Zilla::PluginBundle::DAGOLDEN>.

=head1 CONFIGURATION

Possible options and their default values:

	auto_prereqs   = 1  ; enable AutoPrereqs
	fake_release   = 0  ; if true will use FakeRelease instead of 'releaser'
	install_command = cpanm -v -i . -l ~/perl5 (passed to InstallRelease)
	is_task        = 0  ; set to true to use TaskWeaver instead of PodWeaver
	releaser       = UploadToCPAN
	skip_plugins   =    ; default empty; a regexp of plugin names to exclude
	skip_prereqs   =    ; default empty; corresponds to AutoPrereqs:skip
	weaver_config  = @Author::RWSTAUNER

The C<fake_release> option also respects C<$ENV{DZIL_FAKERELEASE}>.

B<Note> that you can also specify attributes for any of the bundled plugins.
This works like L<Dist::Zilla::Role::Stash::Plugins> except that the role is
not actually used (and there is no stash) because PluginBundles already have
a dynamic configuration.
The option should be the plugin name and the attribute separated by a colon
(or a dot, or any other non-word character(s)).

For example:

	[@Author::RWSTAUNER]
	AutoPrereqs:skip = Bad::Module

B<Note> that this is different than

	[@Author::RWSTAUNER]
	[AutoPrereqs]
	skip = Bad::Module

which will load the plugin a second time.
The first example actually alters the plugin configuration
as it is included by the Bundle.

String (or boolean) attributes will overwrite any in the Bundle:

	[@Author::RWSTAUNER]
	CompileTests.fake_home = 0

Arrayref attributes will be appended to any in the bundle:

	[@Author::RWSTAUNER]
	MetaNoIndex:directory = another-dir

Since the Bundle initializes MetaNoIndex:directory to an arrayref
of directories, C<another-dir> will be appended to that arrayref.

You can overwrite the attribute by adding non-word characters to the end of it:

	[@Author::RWSTAUNER]
	MetaNoIndex:directory@ = another-dir
	; or MetaNoIndex:directory[] = another-dir

You can use any non-word characters: use what makes the most sense to you.
B<Note> that you cannot specify an attribute more than once
(since the configuration is dynamic
and the Bundle cannot predeclare unknown attributes as arrayrefs).

If your situation is more complicated you can use the C<skip_plugins>
attribute to have the Bundle ignore that plugin
and then you can add it yourself:

	[MetaNoIndex]
	directory = one-dir
	directory = another-dir
	[@Author::RWSTAUNER]
	skip_plugins = MetaNoIndex

=head1 EQUIVALENT F<dist.ini>

This bundle is roughly equivalent to:

	[Git::NextVersion]      ; autoincrement version from last tag

	; choose files to include (dzil core [@Basic])
	[GatherDir]             ; everything under top dir
	[PruneCruft]            ; default stuff to skip
	[ManifestSkip]          ; custom stuff to skip

	; munge files
	[Authority]             ; inject $AUTHORITY into modules
	do_metadata = 1         ; default
	[NextRelease]           ; simplify maintenance of Changes file
	format = %v %{yyyy-MM-dd}d
	[PkgVersion]            ; inject $VERSION into modules
	[Prepender]             ; add header to source code files

	[PodWeaver]             ; munge POD in all modules
	config_plugin = @Author::RWSTAUNER
	; 'weaver_config' can be set to an alternate Bundle
	; set 'is_task = 1' to use TaskWeaver instead

	; generate files
	[License]               ; generate distribution files (dzil core [@Basic])
	[Readme]

	; metadata
	[Bugtracker]            ; include bugtracker URL and email address (uses RT)
	[Repository]            ; determine git information (if -e ".git")
	[GithubMeta]            ; overrides [Repository] if repository is on github

	[AutoPrereqs]
	; disable with 'auto_prereqs = 0'

	[MetaNoIndex]           ; encourage CPAN not to index:
	directory = corpus
	directory = examples
	directory = inc
	directory = share
	directory = t
	directory = xt

	[MetaProvides::Package] ; describe packages included in the dist
	meta_noindex = 1        ; ignore things excluded by above MetaNoIndex

	[MinimumPerl]           ; automatically determine Perl version required

	[MetaConfig]            ; include Dist::Zilla info in distmeta (dzil core)
	[MetaYAML]              ; include META.yml (v1.4) (dzil core [@Basic])
	[MetaJSON]              ; include META.json (v2) (more info than META.yml)

	[Prereqs / TestRequires]
	Test::More = 0.96       ; require recent Test::More (including subtests)

	[ExtraTests]            ; build system (dzil core [@Basic])
	[ExecDir]               ; include 'bin/*' as executables
	[ShareDir]              ; include 'share/' for File::ShareDir

	[MakeMaker]             ; create Makefile.PL
	[ModuleBuild]           ; create Build.PL
	[DualBuilders]          ; only require one of the above two (prefer 'build')

	; generate t/ tests
	[CompileTests]          ; make sure .pm files all compile
	fake_home = 1           ; fakes $ENV{HOME} just in case
	[ReportVersions::Tiny]  ; show module versions used in test reports

	; generate xt/ tests
	[CPANChangesTests]      ; Test::CPAN::Changes
	[MetaTests]             ; test META
	[PodSyntaxTests]        ; test POD
	[PodCoverageTests]      ; test documentation coverage
	[Test::Pod::LinkCheck]  ; test Pod links
	[Test::Pod::No404s]     ; test Pod http links
	[PodSpellingTests]      ; spell check POD
	[PortabilityTests]      ; test portability (why? who doesn't use Linux?)
	[KwaliteeTests]         ; CPANTS
	[MinimumVersionTests]   ; test that the automatic plugin worked

	[Manifest]              ; build MANIFEST file (dzil core [@Basic])
	
	; actions for releasing the distribution (dzil core [@Basic])
	[CheckChangesHasContent]
	[TestRelease]           ; run tests before releasing
	[ConfirmRelease]        ; are you sure?
	[UploadToCPAN]
	; set 'fake_release = 1' to use [FakeRelease] instead
	; set 'releaser = AlternatePlugin' to use a different releaser plugin
	; 'fake_release' will override the 'releaser' (useful for sub-bundles)

	[@Git]                  ; use Git bundle to commit/tag/push after releasing
	[InstallRelease]        ; install the new dist (using 'install_command')

=head1 SEE ALSO

=for :list
* L<Dist::Zilla>
* L<Dist::Zilla::Role::PluginBundle::Easy>
* L<Pod::Weaver>

=cut
