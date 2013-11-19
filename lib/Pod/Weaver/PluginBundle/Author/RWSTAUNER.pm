# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;

package Pod::Weaver::PluginBundle::Author::RWSTAUNER;
# ABSTRACT: RWSTAUNER's Pod::Weaver config

use Pod::Weaver::Config::Assembler;
sub _exp { Pod::Weaver::Config::Assembler->expand_package($_[0]) }

sub _plain {
  my ($plug, $arg) = (@_, {});
  (my $name = $plug) =~ s/^\W//;
  return [ $name, _exp($plug), { %$arg } ];
}

sub _bundle_name {
  my $class = @_ ? ref $_[0] || $_[0] : __PACKAGE__;
  join('', '@', ($class =~ /^.+::PluginBundle::(.+)$/));
}

sub mvp_bundle_config {
  ## ($self, $bundle) = @_; $bundle => {payload => {}, name => '@...'}
  my ($self) = @_;
  my @plugins;

  # NOTE: bundle name gets prepended to each plugin name at the end

  push @plugins, (
    # plugin
    _plain('-SingleEncoding'),
    _plain('-WikiDoc'),
    # default
    _plain('@CorePrep'),

    # sections
    # default
    _plain('Name'),
    _plain('Version'),

    # Any pod inside a =begin/end :prelude will go at the top
    [ 'Prelude',     _exp('Region'),  { region_name => 'prelude' } ],
  );

  for my $plugin (
    # default
    [ 'Synopsis',    _exp('Generic'), {} ],
    [ 'Description', _exp('Generic'), {} ],
    [ 'Overview',    _exp('Generic'), {} ],
    # extra
    [ 'Usage',       _exp('Generic'), {} ],

    ['Class Methods',_exp('Collect'), { command => 'class_method' } ], # header => 'CLASS METHODS',
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
    # see prelude above
    [ 'Postlude',    _exp('Region'),    { region_name => 'postlude' } ],

    # TODO: consider SeeAlso if it ever allows comments with the links

    # extra
    # include Support section with various cpan links and github repo
    [ 'Support',     _exp('Support'),
      {
        ':version' => '1.005', # metacpan
        repository_content => '',
        repository_link => 'both',
        # metacpan links to everything else
        websites => [ qw(metacpan) ],
      }
    ],

    [ 'Acknowledgements', _exp('Generic'), {header => 'ACKNOWLEDGEMENTS'} ],

    _plain('Authors'),
    _plain('Contributors'),

    _plain('Legal'),

    # plugins
    [ 'List',        _exp('-Transformer'), { 'transformer' => 'List' } ],

    _plain('-StopWords', {
      ':version' => '1.005', # after =encoding
      # my dictionary doesn't like that extra 'E' but it looks funny without it
      include => 'ACKNOWLEDGEMENTS'
    }),
  );

  # prepend bundle name to each plugin name
  my $name = $self->_bundle_name;
  @plugins = map { $_->[0] = "$name/$_->[0]"; $_ } @plugins;

  return @plugins;
}

1;

=for Pod::Coverage mvp_bundle_config

=head1 SYNOPSIS

  ; weaver.ini

  [@Author::RWSTAUNER]

or with a F<dist.ini> like so:

  ; dist.ini

  [@Author::RWSTAUNER]

you don't need a F<weaver.ini> at all.

=head1 ROUGHLY EQUIVALENT

This bundle is roughly equivalent to:

=bundle_ini_string

=cut
