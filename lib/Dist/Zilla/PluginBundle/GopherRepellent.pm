package Dist::Zilla::PluginBundle::GopherRepellent;
# ABSTRACT: keep those pesky gophers out of your dists!

use strict;
use warnings;
use Moose;
use Moose::Autobox;
use Dist::Zilla 4.102345;
with 'Dist::Zilla::Role::PluginBundle::Easy';

use Dist::Zilla::PluginBundle::Basic (); # use most of the plugins included
use Dist::Zilla::Plugin::Authority 1.001 ();
use Dist::Zilla::Plugin::Bugtracker ();
#use Dist::Zilla::Plugin::CheckExtraTests ();
use Dist::Zilla::Plugin::CompileTests 1.100740 ();
use Dist::Zilla::Plugin::Git::DescribeVersion 0.006 ();
use Dist::Zilla::Plugin::GitFmtChanges 0.003 ();
use Dist::Zilla::Plugin::GithubMeta 0.10 ();
use Dist::Zilla::Plugin::KwaliteeTests ();
use Dist::Zilla::Plugin::MetaNoIndex 1.101130 ();
use Dist::Zilla::Plugin::MetaProvides::Package 1.11044404 ();
use Dist::Zilla::Plugin::MinimumPerl 0.02 ();
use Dist::Zilla::Plugin::MinimumVersionTests ();
use Dist::Zilla::Plugin::PkgVersion ();
use Dist::Zilla::Plugin::PodCoverageTests ();
use Dist::Zilla::Plugin::PodSpellingTests ();
use Dist::Zilla::Plugin::PodSyntaxTests ();
use Dist::Zilla::Plugin::PodWeaver ();
use Dist::Zilla::Plugin::PortabilityTests ();
use Dist::Zilla::Plugin::Repository 0.16 (); # deprecates github_http
use Dist::Zilla::Plugin::TaskWeaver 0.101620 ();
use Pod::Weaver::PluginBundle::GopherRepellent ();

our $NAME = join('', '@', (__PACKAGE__ =~ /([^:]+)$/));

# attributes

has auto_prereqs => (
	is      => 'ro',
	isa     => 'Bool',
	lazy    => 1,
	default => sub {
		exists $_[0]->payload->{auto_prereqs}
		     ? $_[0]->payload->{auto_prereqs}
			 : 1
	}
);

has fake_release => (
	is      => 'ro',
	isa     => 'Bool',
	lazy    => 1,
	default => sub { $_[0]->payload->{fake_release} || $ENV{DZIL_FAKERELEASE} }
);

has is_task => (
	is      => 'ro',
	isa     => 'Bool',
	lazy    => 1,
	default => sub { $_[0]->payload->{is_task} }
);

has releaser => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub { $_[0]->payload->{releaser} || 'UploadToCPAN' }
);

has skip_prereqs => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub { $_[0]->payload->{skip_prereqs} || '' }
);

has weaver_config => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub { $_[0]->payload->{weaver_config} || $NAME }
);

sub configure {
	my ($self) = @_;

	$self->log_fatal("you must not specify both weaver_config and is_task")
		if $self->is_task and $self->weaver_config ne $NAME;

	$self->add_plugins(
	
	# provide version
		'Git::DescribeVersion',

	# gather and prune
		qw(
			GatherDir
			PruneCruft
			ManifestSkip
		),

	# munge files
		[ 'Authority' => { do_metadata => 1 }],
		'PkgVersion',
		# 'Prepender' 1.100960
		( $self->is_task
			?  'TaskWeaver'
			: [ 'PodWeaver' => { config_plugin => $self->weaver_config } ]
		),

	# generated distribution files
		qw(
			License
			Readme
		),
		[
			GitFmtChanges => {
				file_name  => 'Changes',
				log_format => 'format:%h %s%n'
			}
		],
		# @APOCALYPTIC: generate MANIFEST.SKIP ?

	# metadata
		'Bugtracker',
		# won't find git if not in repository root (!-e ".git")
		'Repository',
		# overrides [Repository] if repository is on github
		'GithubMeta',

		( $self->auto_prereqs
			? [ 'AutoPrereqs' => $self->config_slice({ skip_prereqs => 'skip' }) ]
			: ()
		),
		[
			MetaNoIndex => {
				directory => [qw/corpus examples inc share t xt/],
#				'package' => [qw/DB/]
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
		),

		#;[ModuleBuild]
		#;[DualBuilders]
		#;prefer = make

	# generated t/ tests
		[ CompileTests => { fake_home => 1 } ],
		# ReportVersions::Tiny 1.01

	# generated xt/ tests
		qw(
			MetaTests
			PodSyntaxTests
			PodCoverageTests
			PodSpellingTests
			PortabilityTests
			KwaliteeTests
			MinimumVersionTests
		),

	# manifest: must come after all generated files
		'Manifest',

	# before release
			#CheckExtraTests
		qw(
			TestRelease
			ConfirmRelease
		),

	# release
	# @Apocalyptic: -e File::Spec->catfile( File::HomeDir->my_home, '.pause' )
	#            or -e File::Spec->catfile( '.', '.pause' ) )
		( $self->fake_release ? 'FakeRelease' : $self->releaser ),
	);

#	$self->add_bundle('@Git' => {
#		tag_format => '%v',
#		push_to    => [ qw(origin github) ],
#	});

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=for stopwords PluginBundle PluginBundles DAGOLDEN RJBS dists ini

=for Pod::Coverage configure

=head1 SYNOPSIS

	# dist.ini

	[@GopherRepellent]

=head1 DESCRIPTION

This is a L<Dist::Zilla::PluginBundle|Dist::Zilla::Role::PluginBundle::Easy>
to help keep those pesky gophers away from your dists.

It is roughly equivalent to:

	[Git::DescribeVersion]  ; count commits from last tag to provide version

	; choose files to include (dzil core [@Basic])
	[GatherDir]             ; everything under top dir
	[PruneCruft]            ; default stuff to skip
	[ManifestSkip]          ; custom stuff to skip

	; munge files
	[PkgVersion]            ; inject $VERSION into modules

	[PodWeaver]             ; munge POD in all modules
	config_plugin = @GopherRepellent
	; 'weaver_config' can be set to an alternate Bundle
	; set 'is_task = 1' to use TaskWeaver instead

	; generate files
	[License]               ; generate distribution files (dzil core [@Basic])
	[Readme]
	[GitFmtChanges]         ; generate a Changes file from git log --oneline
	file_name = Changes
	log_format = format:%h %s%n

	; metadata
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

	[ExtraTests]            ; build system (dzil core [@Basic])
	[ExecDir]               ; include 'bin/*' as executables
	[ShareDir]              ; include 'share/' for File::ShareDir
	[MakeMaker]             ; create Makefile.PL

	; generate t/ tests
	[CompileTests]          ; make sure .pm files all compile
	fake_home = 1           ; fakes $ENV{HOME} just in case

	; generate xt/ tests
	[MetaTests]             ; test META
	[PodSyntaxTests]        ; test POD
	[PodCoverageTests]      ; test documentation coverage
	[PodSpellingTests]      ; spell check POD
	[PortabilityTests]      ; test portability (why? who doesn't use Linux?)
	[KwaliteeTests]         ; CPANTS
	[MinimumVersionTests]   ; test that the automatic plugin worked

	[Manifest]              ; build MANIFEST file (dzil core [@Basic])
	
	; actions for releasing the distribution (dzil core [@Basic])
	[TestRelease]           ; run tests before releasing
	[ConfirmRelease]        ; are you sure?
	[UploadToCPAN]
	; set 'fake_release = 1' to use [FakeRelease] instead
	; set 'releaser = AlternatePlugin' to use a different releaser plugin
	; 'fake_release' will override the 'releaser' (useful for sub-bundles)

This Bundle was heavily influenced by the bundles of
L<RJBS|Dist::Zilla::PluginBundle::RJBS> and
L<DAGOLDEN|Dist::Zilla::PluginBundle::DAGOLDEN>.

=head1 RATIONALE

I built my own PluginBundles
after my ini files started getting unruly.

It also made sense to me to build a separate
PluginBundle for C<$work> which could use this one
and then set a few attributes.

This bundle is essentially C<BeLike::RWSTAUNER>.
(Who would want to do that?)

It is subject to change.

I am still new to L<Dist::Zilla>
and uploading to CPAN
and am trying to learn how to make
good/quality/L<kwalitee|Module::CPANTS::Analyse> modules.

Therefore this bundle may be useful for others
who aren't quite sure what they want or how they want it,
but would like to have as much generated as possible to make a "complete" dist.

Beyond that audience
this may be mostly for my own use
(and for people I work with who are less inclined to roll their own),
but perhaps my choices and documentation will help others along the way
(or encourage someone to set me straight).

=head1 SEE ALSO

=for :list
* L<Dist::Zilla>
* L<Pod::Weaver>
* L<http://www.lucasarts.com/games/monkeyisland>
The Secret of Monkey Island (E<copy> Lucas Arts)
- the inspiration for the name of this bundle

=cut
