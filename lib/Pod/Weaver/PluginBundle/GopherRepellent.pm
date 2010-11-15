package Pod::Weaver::PluginBundle::GopherRepellent;
# ABSTRACT: keep those pesky gophers out of your POD!

use strict;
use warnings;

use Pod::Weaver::PluginBundle::Default ();
#use Pod::Weaver::Plugin::WikiDoc ();
use Pod::Weaver::Section::Support 1.001 (); # not on CPAN
use Pod::Elemental::Transformer::List ();

use Pod::Weaver::Config::Assembler;
sub _exp { Pod::Weaver::Config::Assembler->expand_package($_[0]) }

# TODO: use modules

our $NAME = join('', '@', (__PACKAGE__ =~ /([^:]+)$/));

sub mvp_bundle_config {
  my @plugins;
  push @plugins, (
    #[ "$NAME/WikiDoc",     _exp('-WikiDoc'), {} ],
    [ "$NAME/CorePrep",    _exp('@CorePrep'), {} ],
    [ "$NAME/Name",        _exp('Name'),      {} ],
    [ "$NAME/Version",     _exp('Version'),   {} ],

    [ "$NAME/Prelude",     _exp('Region'),  { region_name => 'prelude'     } ],
    [ "$NAME/Synopsis",    _exp('Generic'), { header      => 'SYNOPSIS'    } ],
    [ "$NAME/Description", _exp('Generic'), { header      => 'DESCRIPTION' } ],
    [ "$NAME/Overview",    _exp('Generic'), { header      => 'OVERVIEW'    } ],

    #[ "$NAME/Stability",   _exp('Generic'), { header      => 'STABILITY'   } ],
  );

  for my $plugin (
    [ 'Attributes', _exp('Collect'), { command => 'attr'   } ],
    [ 'Methods',    _exp('Collect'), { command => 'method' } ],
    [ 'Functions',  _exp('Collect'), { command => 'func'   } ],
  ) {
    $plugin->[2]{header} = uc $plugin->[0];
    push @plugins, $plugin;
  }

  push @plugins, (
	# include Support section with various cpan links and github repo
    [ "$NAME/Support",   _exp('Support'),
		{
			repository_content => '',
			repository_link => 'both'
		}
	],

    [ "$NAME/Leftovers", _exp('Leftovers'), {} ],
    [ "$NAME/postlude",  _exp('Region'),    { region_name => 'postlude' } ],
    [ "$NAME/Authors",   _exp('Authors'),   {} ],
    [ "$NAME/Legal",     _exp('Legal'),     {} ],
    [ "$NAME/List",      _exp('-Transformer'), { 'transformer' => 'List' } ],
  );

  return @plugins;
}

1;

=for Pod::Coverage mvp_bundle_config

=head1 DESCRIPTION

Roughly equivalent to:

	; like @Default {
	[@CorePrep]

	[Name]
	[Version]

	[Region  / prelude]

	[Generic / SYNOPSIS]
	[Generic / DESCRIPTION]
	[Generic / OVERVIEW]

	[Collect / ATTRIBUTES]
	command = attr

	[Collect / METHODS]
	command = method

	[Collect / FUNCTIONS]
	command = func

	[Leftovers]

	[Region  / postlude]

	; custom section
	[Support]
	repository_content =
	repository_link = both

	; finish @Default
	[Authors]
	[Legal]
	; } end of @Default

	; append customizations
	[-Transformer]
	transformer = List

=cut
