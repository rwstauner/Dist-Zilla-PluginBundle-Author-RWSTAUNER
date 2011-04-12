package Pod::Weaver::PluginBundle::Author::RWSTAUNER;
# ABSTRACT: RWSTAUNER's Pod::Weaver config

use strict;
use warnings;

use Pod::Weaver 3.101632 ();
use Pod::Weaver::PluginBundle::Default ();
use Pod::Weaver::Plugin::StopWords 1.001005 ();
use Pod::Weaver::Plugin::Transformer ();
use Pod::Weaver::Plugin::WikiDoc ();
use Pod::Weaver::Section::Support 1.001 ();
use Pod::Elemental 0.102360 ();
use Pod::Elemental::Transformer::List ();

use Pod::Weaver::Config::Assembler;
sub _exp { Pod::Weaver::Config::Assembler->expand_package($_[0]) }

sub _plain {
	my ($plug) = @_;
	(my $name = $plug) =~ s/^\W//;
	return [ $name, _exp($plug), {} ];
}

sub _bundle_name {
	my $class = @_ ? ref $_[0] || $_[0] : __PACKAGE__;
	join('', '@', ($class =~ /([^:]+)$/));
}

sub mvp_bundle_config {
	my ($self, $bundle) = @_;
	my @plugins;

	# NOTE: bundle name gets prepended to each plugin name at the end

	push @plugins, (
		# plugin
		_plain('-WikiDoc'),
		# default
		_plain('@CorePrep'),

		# sections
		# default
		_plain('Name'),
		_plain('Version'),

		[ 'Prelude',     _exp('Region'),  { region_name => 'prelude' } ],
	);

	for my $plugin (
		# default
		[ 'Synopsis',    _exp('Generic'), {} ],
		[ 'Description', _exp('Generic'), {} ],
		[ 'Overview',    _exp('Generic'), {} ],
		# extra
		[ 'Usage',       _exp('Generic'), {} ],

		# default
		[ 'Attributes',  _exp('Collect'), { command => 'attr'   } ],
		[ 'Methods',     _exp('Collect'), { command => 'method' } ],
		[ 'Functions',   _exp('Collect'), { command => 'func'   } ],
	) {
		$plugin->[2]{header} = uc $plugin->[0];
		push @plugins, $plugin;
	}

	# default
	push @plugins, (
		_plain('Leftovers'),
		[ 'Postlude',    _exp('Region'),    { region_name => 'postlude' } ],

		# TODO: consider SeeAlso if it ever allows comments with the links

		# extra
		# include Support section with various cpan links and github repo
		[ 'Support',     _exp('Support'),
			{ repository_content => '', repository_link => 'both' }
		],

		# default
		_plain('Authors'),
		_plain('Legal'),

		# plugins
		[ 'List',        _exp('-Transformer'), { 'transformer' => 'List' } ],
		_plain('-StopWords'),
	);

	# prepend bundle name to each plugin name
	my $name = $self->_bundle_name;
	@plugins = map { $_->[0] = "$name/$_->[0]"; $_ } @plugins;

	return @plugins;
}

1;

=for stopwords PluginBundle WikiDoc

=for Pod::Coverage mvp_bundle_config

=begin :prelude

=head1 DEPRECATED

This module is deprecated.
It will soon be renamed into the Author namespace.

=end :prelude

=head1 SYNOPSIS

	# weaver.ini

	[@Author::RWSTAUNER]

or with a F<dist.ini> like so:

	# dist.ini

	[@Author::RWSTAUNER]

you don't need a F<weaver.ini> at all.

=head1 DESCRIPTION

This PluginBundle is like the @Default
with the following additions:

=for :list
* Inserts a SUPPORT section to the POD just before AUTHOR
* Adds the List Transformer
* Enables WikiDoc formatting
* Generates and collects stopwords

It is roughly equivalent to:

	[WikiDoc]                 ; transform wikidoc sections to POD
	[@CorePrep]               ; [@Default]

	[Name]                    ; [@Default]
	[Version]                 ; [@Default]

	[Region  / prelude]       ; [@Default]

	[Generic / SYNOPSIS]      ; [@Default]
	[Generic / DESCRIPTION]   ; [@Default]
	[Generic / OVERVIEW]      ; [@Default]
	[Generic / USAGE]         ; Put USAGE section near the top

	[Collect / ATTRIBUTES]    ; [@Default]
	command = attr

	[Collect / METHODS]       ; [@Default]
	command = method

	[Collect / FUNCTIONS]     ; [@Default]
	command = func

	[Leftovers]               ; [@Default]

	[Region  / postlude]      ; [@Default]

	; custom section
	[Support]                 ; =head1 SUPPORT (bugs, cpants, git...)
	repository_content =
	repository_link = both

	[Authors]                 ; [@Default]
	[Legal]                   ; [@Default]

	[-Transformer]            ; enable =for :list
	transformer = List

	[-StopWords]              ; generate some stopwords and gather them together

=cut
