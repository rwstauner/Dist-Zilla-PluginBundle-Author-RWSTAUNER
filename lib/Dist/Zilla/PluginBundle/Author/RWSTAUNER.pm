# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;

package Dist::Zilla::PluginBundle::Author::RWSTAUNER;
# ABSTRACT: RWSTAUNER's Dist::Zilla config

use Moose;
use List::Util qw(first); # core

with qw(
  Dist::Zilla::Role::PluginBundle::Easy
  Dist::Zilla::Role::PluginBundle::Config::Slicer
  Dist::Zilla::Role::PluginBundle::PluginRemover
);
# Dist::Zilla::Role::DynamicConfig is not necessary: payload is already dynamic

# don't require it in case it won't install somewhere
my $spelling_tests = eval 'require Dist::Zilla::Plugin::Test::PodSpelling';

# available builders
my %builders = (
  eumm => 'MakeMaker',
  mb   => 'ModuleBuild',
);

# cannot use $self->name for class methods
sub _bundle_name {
  my $class = @_ ? ref $_[0] || $_[0] : __PACKAGE__;
  join('', '@', ($class =~ /^.+::PluginBundle::(.+)$/));
}

# TODO: consider an option for using ReportPhase
sub _default_attributes {
  use Moose::Util::TypeConstraints 1.01;
  return {
    auto_prereqs    => [Bool => 1],
    fake_release    => [Bool => $ENV{DZIL_FAKERELEASE}],
    # cpanm will choose the best place to install
    install_command => [Str  => 'cpanm -v -i .'],
    is_task         => [Bool => 0],
    open_source     => [Bool => 1],
    placeholder_comments => [Bool => 0],
    skip_plugins    => [Str  => ''],
    weaver_config   => [Str  => $_[0]->_bundle_name],
    use_git_bundle  => [Bool => 1],
    max_target_perl => [Str  => '5.008'],
    builder         => [enum( [ both => keys %builders ] ) => 'eumm'],
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

has releaser => (
  is         => 'ro',
  isa        => 'Str',
  lazy       => 1,
  default    => sub {
    my ($self) = @_;
    exists $self->payload->{releaser}
      ?    $self->payload->{releaser}
      :    $self->open_source ? 'UploadToCPAN' : '';
  },
);

{
  # generate attributes
  __PACKAGE__->_generate_attribute($_)
    for keys %{ __PACKAGE__->_default_attributes };
}

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  my $attr = $class->$orig(@args);

  # removed attributes
  my %deprecated = (
    disable_tests => '-remove',
    skip_prereqs  => 'AutoPrereqs.skip',
  );
  while( my ($old, $new) = each %deprecated ){
    if( exists $attr->{payload}{ $old } ){
      die "$class no longer supports '$old'.\n  Please use '$new' instead.\n";
    }
  }
  return $attr;
};

# main
after configure => sub {
  my ($self) = @_;

  # TODO: accept this from ENV
  my $skip = $self->skip_plugins;
  $skip &&= qr/$skip/;

  my $dynamic = $self->payload;
  # sneak this config in behind @TestingMania's back
  $dynamic->{'Test::Compile.fake_home'} = 1
    unless first { /Test::Compile\W+fake_home/ } keys %$dynamic;

  my $plugins = $self->plugins;

  my $i = -1;
  while( ++$i < @$plugins ){
    my $spec = $plugins->[$i] or next;
    # NOTE: $conf retains its reference (modifications alter $spec)
    my ($name, $class, $conf) = @$spec;

    # ignore the prefix (@Bundle/Name => Name) (DZP::Name => Name)
    my ($alias)   = ($name  =~ m#([^/]+)$#);
    my ($moniker) = ($class =~ m#^(?:Dist::Zilla::Plugin(?:Bundle)?::)?(.+)$#);

    # exclude any plugins that match 'skip_plugins'
    if( $skip ){
      # match on full name or plugin class (regexp should use \b not \A)
      if( $name =~ $skip || $class =~ $skip ){
        splice(@$plugins, $i, 1);
        redo;
      }
    }
  }
  if ( $ENV{DZIL_BUNDLE_DEBUG} ) {
    eval {
      require YAML::Tiny; # dzil requires this
      $self->log( YAML::Tiny::Dump( $self->plugins ) );
    };
    warn $@ if $@;
  }
};

sub configure {
  my ($self) = @_;

  $self->log_fatal("you must not specify both weaver_config and is_task")
    if $self->is_task and $self->weaver_config ne $self->_bundle_name;

  $self->add_plugins(

  # provide version
    #'Git::DescribeVersion',
    'Git::NextVersion',

  # gather and prune
    $self->_generate_manifest_skip,
    qw(
      GatherDir
      PruneCruft
      ManifestSkip
    ),
    # Devel::Cover db does not need to be packaged with distribution
    [ PruneFiles => 'PruneDevelCoverDatabase' => { match => '^(cover_db/.+)' } ],
    # Code::Stat report
    [ PruneFiles => 'PruneCodeStatCollection' => { match => '^codestat\.out' } ],
    # generated tags file... useful for development but noisy to commit
    [ PruneFiles => 'PruneTags' => { match => '^tags$' } ],

  # munge files
    [
      Authority => {
        ':version'     => '1.005', # accepts any non-whitespace + locate_comment
        do_munging     => 1,
        do_metadata    => 1,
        locate_comment => $self->placeholder_comments,
      }
    ],
    [
      NextRelease => {
        # w3cdtf
        time_zone => 'UTC',
        format => q[%-9V %{yyyy-MM-dd'T'HH:mm:ss'Z'}d],
      }
    ],
    'Git::Describe',
    ($self->placeholder_comments ? 'OurPkgVersion' : 'PkgVersion'),
    [
      Prepender => {
        ':version' => '1.112280', # 'skip' attribute
        # don't prepend to tests
        skip => '^x?t/.+',
      }
    ],
    ( $self->is_task
      ?  'TaskWeaver'
      # TODO: detect weaver.ini and skip 'config_plugin'?
      : [ 'PodWeaver' => { config_plugin => $self->weaver_config } ]
    ),

  # generated distribution files
    qw(
      License
      Readme
    ),
  );

  $self->add_plugins(
    [
      # generate README.pod in repo root for github
      ReadmeAnyFromPod => {
        ':version' => '0.120120',
        type       => 'pod',
        location   => 'root',
      }
    ],

  # metadata
    'Bugtracker',
    # won't find git if not in repository root (!-e ".git")
    [ Repository => { ':version' => '0.16' } ], # deprecates github_http
    # overrides [Repository] if repository is on github
    [ GithubMeta => { ':version' => '0.10' } ],
    [ ContributorsFromGit => { ':version' => '0.005' } ],
  ) if $self->open_source;

  $self->add_plugins('AutoPrereqs')
    if $self->auto_prereqs;

  $self->add_plugins(
#   [ 'MetaData::BuiltWith' => { show_uname => 1 } ], # currently DZ::Util::EmulatePhase causes problems
    [
      MetaNoIndex => {
        ':version' => 1.101130,
        # could use grep { -d $_ } but that will miss any generated files
        directory => [qw(corpus examples inc share t xt)],
        namespace => [qw(Local t::lib)],
        'package' => [qw(DB)],
      }
    ],
    [   # AFTER MetaNoIndex
      'MetaProvides::Package' => {
        ':version'   => '1.14000001',
        meta_noindex => 1
      }
    ],

    [ MinimumPerl => { ':version' => '1.003' } ],
    qw(
      MetaConfig
      MetaYAML
      MetaJSON
    ),

# I prefer to be explicit about required versions when loading, but this is a handy example:
#    [
#      Prereqs => 'TestMoreWithSubtests' => {
#        -phase => 'test',
#        -type  => 'requires',
#        'Test::More' => '0.96'
#      }
#    ],

  # build system
    qw(
      ExecDir
      ShareDir
    ),
  );

  {
    my @builders = $self->builder eq 'both'
      ? (values %builders, 'DualBuilders')
      : ($builders{ $self->builder });
    $self->log("Including builders: @builders\n");
    $self->add_plugins(@builders);
  }

  $self->add_plugins(
  # generated t/ tests
    [ 'Test::ReportPrereqs' => { ':version' => '0.004' } ], # include/exclude
  );

  $self->add_plugins(
    [ 'Test::ChangesHasContent' => { ':version' => '0.006' } ], # version-TRIAL

  # generated xt/ tests
    # Test::Pod::Spelling::CommonMistakes ?
      #Test::Pod::No404s # removed since it's rarely useful
  ) if $self->open_source;

  if ( $spelling_tests ) {
    $self->add_plugins('Test::PodSpelling');
  }
  else {
    $self->log("Test::PodSpelling Plugin failed to load.  Pleese dunt mayke ani misteaks.\n");
  }

  # TestingMania is primarily code/dist quality checks.
  if( $self->open_source ){
    # NOTE: A newer TestingMania might duplicate plugins if new tests are added
    $self->add_bundle('@TestingMania' => {
      ':version'      => '0.019', # max_target_perl
      max_target_perl =>     $self->max_target_perl,
    });
  }
  # These are for your own protection.
  else {
    $self->add_plugins(
      qw(
        Test::Compile
        Test::MinimumVersion
        PodSyntaxTests
      ),
    );
  }

  $self->add_plugins(
  # manifest: must come after all generated files
    'Manifest',

  # before release
    qw(
      CheckExtraTests
    ),
  );

  $self->add_plugins(
    [ CheckChangesHasContent => { ':version' => '0.006' } ], # version-TRIAL
    qw(
      CheckMetaResources
      CheckPrereqsIndexed
    )
  ) if $self->open_source;

  $self->add_plugins(
    qw(
      TestRelease
    ),
  );

  # defaults: { tag_format => '%v', push_to => [ qw(origin) ] }
  $self->add_bundle('@Git' => {
    ':version' => '2.004', # improved changelog parsing
    allow_dirty => [qw(Changes README.pod)],
    commit_msg  => 'v%v%t%n%n%c'
  })
    if $self->use_git_bundle;

  $self->add_plugins(
    qw(
      ConfirmRelease
    ),
  );

  # release
  my $releaser = $self->fake_release ? 'FakeRelease' : $self->releaser;
  # ignore releaser if it's set to empty string
  $self->add_plugins($releaser)
    if $releaser;

  $self->add_plugins(
    [ InstallRelease => { ':version' => '0.006', install_command => $self->install_command } ]
  )
    if $self->install_command;

}

# As of Dist::Zilla 4.102345 pluginbundles don't have log and log_fatal methods
foreach my $method ( qw(log log_fatal) ){
  unless( __PACKAGE__->can($method) ){
    no strict 'refs'; ## no critic (NoStrict)
    *$method = $method =~ /fatal/
      ? sub { die($_[1]) }
      : sub { warn("[${\$_[0]->_bundle_name}] $_[1]") };
  }
}

sub _generate_manifest_skip {
  # include a default MANIFEST.SKIP for the tests and/or historical reasons
  return [
    GenerateFile => 'GenerateManifestSkip' => {
      filename => 'MANIFEST.SKIP',
      is_template => 1,
      content => <<'EOF_MANIFEST_SKIP',

\B\.git\b
\B\.gitignore$
^[\._]build
^blib/
^(Build|Makefile)$
\bpm_to_blib$
^MYMETA\.

EOF_MANIFEST_SKIP
    }
  ];
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=for Pod::Coverage configure
log log_fatal

=head1 SYNOPSIS

  # dist.ini

  [@Author::RWSTAUNER]

=head1 DESCRIPTION

This is an Author
L<Dist::Zilla::PluginBundle|Dist::Zilla::Role::PluginBundle::Easy>
that I use for building my distributions.

=head1 CONFIGURATION

Possible options and their default values:

  auto_prereqs   = 1  ; enable AutoPrereqs
  builder        = eumm ; or 'mb' or 'both'
  fake_release   = 0  ; if true will use FakeRelease instead of 'releaser'
  install_command = cpanm -v -i . (passed to InstallRelease)
  is_task        = 0  ; set to true to use TaskWeaver instead of PodWeaver
  open_source    = 1  ; include plugins for cpan/meta/repo/xt/change log, etc
  placeholder_comments = 0 ; use '# VERSION' and '# AUTHORITY' comments
  releaser       = UploadToCPAN
  skip_plugins   =    ; default empty; a regexp of plugin names to exclude
  weaver_config  = @Author::RWSTAUNER

The C<fake_release> option also respects C<$ENV{DZIL_FAKERELEASE}>.

B<NOTE>:
This bundle consumes L<Dist::Zilla::Role::PluginBundle::Config::Slicer>
so you can also specify attributes for any of the bundled plugins.
The option should be the plugin name and the attribute separated by a dot:

  [@Author::RWSTAUNER]
  AutoPrereqs.skip = Bad::Module

B<Note> that this is different than

  [@Author::RWSTAUNER]
  [AutoPrereqs]
  skip = Bad::Module

which will load the plugin a second time.
The first example actually alters the plugin configuration
as it is included by the Bundle.

See L<Config::MVP::Slicer/CONFIGURATION SYNTAX> for more information.

If your situation is more complicated you can use the C<-remove> attribute
(courtesy of L<Dist::Zilla::Role::PluginBundle::PluginRemover>)
to have the Bundle ignore that plugin
and then you can add it yourself:

  [MetaNoIndex]
  directory = one-dir
  directory = another-dir
  [@Author::RWSTAUNER]
  -remove = MetaNoIndex

C<-remove> can be specified multiple times.

Alternatively you can use the C<skip_plugins> attribute (only once)
which is a regular expression that matches plugin name or package.

  [@Author::RWSTAUNER]
  skip_plugins = MetaNoIndex|SomethingElse

=head1 ROUGHLY EQUIVALENT

This bundle is roughly equivalent to the following (generated) F<dist.ini>:

=bundle_ini_string

=head1 SEE ALSO

=for :list
* L<Dist::Zilla>
* L<Dist::Zilla::Role::PluginBundle::Easy>
* L<Dist::Zilla::Role::PluginBundle::Config::Slicer>
* L<Dist::Zilla::Role::PluginBundle::PluginRemover>
* L<Pod::Weaver>

=cut
