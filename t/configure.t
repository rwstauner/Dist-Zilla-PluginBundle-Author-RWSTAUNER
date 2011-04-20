# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More 0.96;

my $NAME = 'Author::RWSTAUNER';
my $BNAME = "\@$NAME";
my $mod = "Dist::Zilla::PluginBundle::$NAME";
eval "require $mod" or die $@;

# get default MetaNoIndex hashref
my $noindex = (grep { ref($_) && $_->[0] =~ 'MetaNoIndex' }
  @{ init_bundle({})->plugins })[0]->[-1];
my $noindex_dirs = $noindex->{directory};

# test attributes that change plugin configurations
my %default_exp = (
  CompileTests            => {fake_home => 1},
  PodWeaver               => {config_plugin => $BNAME},
  AutoPrereqs             => {},
  MetaNoIndex             => {%$noindex, directory => [@$noindex_dirs]},
  'MetaProvides::Package' => {meta_noindex => 1},
);

foreach my $test (
  [{}, {%default_exp}],
  [{'skip_prereqs'     => 'Goober'},            { %default_exp, AutoPrereqs => {skip => 'Goober'} }],
  [{'AutoPrereqs:skip' => 'Goober'},            { %default_exp, AutoPrereqs => {skip => 'Goober'} }],
  [{'MetaNoIndex:directory'  => 'goober'},      { %default_exp, MetaNoIndex => {%$noindex, directory => [@$noindex_dirs, 'goober']} }],
  [{'MetaNoIndex:directory@' => 'goober'},      { %default_exp, MetaNoIndex => {%$noindex, directory => ['goober']} }],
  [{'CompileTests->fake_home' => 0},            { %default_exp, CompileTests => {fake_home => 0} }],
  [{'MetaProvides::Package:meta_noindex' => 0}, { %default_exp, 'MetaProvides::Package' => {meta_noindex => 0} }],
  [{weaver_config => '@Default', 'MetaNoIndex:directory[]' => 'arr'}, {
    PodWeaver => {config_plugin => '@Default'},
    MetaNoIndex => {%$noindex, directory => ['arr']} }],
){
  my ($config, $exp) = @$test;

  my @plugins = @{init_bundle($config)->plugins};

  foreach my $plugin ( @plugins ){
    my ($moniker, $name, $payload) = @$plugin;
    my ($plugname) = ($moniker =~ /^$BNAME\/(.+)$/);

    if( exists $exp->{$plugname} ){
      is_deeply($payload, $exp->{$plugname}, 'expected configuration')
    }
  }
}

# test attributes that alter which plugins are included
{
  my $bundle = init_bundle({});
  my $test_name = 'expected plugins included';
  ok( has_plugin($bundle, 'PodWeaver'),    $test_name);
  ok( has_plugin($bundle, 'AutoPrereqs'),  $test_name);
  ok( has_plugin($bundle, 'CompileTests'), $test_name);
  ok( has_plugin($bundle, 'ExtraTests'),   $test_name);
  ok(!has_plugin($bundle, 'FakeRelease'),  $test_name);
  ok( has_plugin($bundle, 'UploadToCPAN'), $test_name);
  ok( has_plugin($bundle, 'CompileTests'), $test_name);

  $bundle = init_bundle({auto_prereqs => 0});
  ok(!has_plugin($bundle, 'AutoPrereqs'),  $test_name);

  $bundle = init_bundle({fake_release => 1});
  ok( has_plugin($bundle, 'FakeRelease'),  $test_name);
  ok(!has_plugin($bundle, 'UploadToCPAN'), $test_name);

  $bundle = init_bundle({is_task => 1});
  ok( has_plugin($bundle, 'TaskWeaver'),   $test_name);
  ok(!has_plugin($bundle, 'PodWeaver'),    $test_name);

  $bundle = init_bundle({releaser => 'Goober'});
  ok( has_plugin($bundle, 'Goober'),       $test_name);
  ok(!has_plugin($bundle, 'UploadToCPAN'), $test_name);

  $bundle = init_bundle({skip_plugins => '\b(CompileTests|ExtraTests|GenerateManifestSkip)$'});
  ok(!has_plugin($bundle, 'CompileTests'), $test_name);
  ok(!has_plugin($bundle, 'ExtraTests'),   $test_name);
  ok(!has_plugin($bundle, 'GenerateManifestSkip', 1),   $test_name);

  $bundle = init_bundle({disable_tests => 'EOLTests,CompileTests'});
  ok(!has_plugin($bundle, 'EOLTests'),     $test_name);
  ok(!has_plugin($bundle, 'CompileTests'), $test_name);
  ok( has_plugin($bundle, 'NoTabsTests'),  $test_name);
}

# test releaser
foreach my $releaser (
  [{},                                        'UploadToCPAN'],
  [{fake_release => 1},                       'FakeRelease'],
  [{releaser => 'Goober'},                    'Goober'],
  # fake_release wins
  [{releaser => 'Goober', fake_release => 1}, 'FakeRelease'],
){
  my ($config, $exp) = @$releaser;
  releaser_is(init_bundle($config), $exp);
  # env always overrides
  local $ENV{DZIL_FAKERELEASE} = 1;
  releaser_is(init_bundle($config), 'FakeRelease');
}

done_testing;

# helper subs
sub has_plugin {
  my ($bundle, $plug, $by_name) = @_;
  # default to plugin module, but allow searching by name
  my $index = $by_name ? 0 : 1;
  # should use List::Util::any
  scalar grep { $_->[$index] =~ /\b($plug)$/ } @{$bundle->plugins};
}
sub init_bundle {
  my $bundle = $mod->new(name => $BNAME, payload => $_[0]);
  isa_ok($bundle, $mod);
  $bundle->configure;
  return $bundle;
}
sub releaser_is {
  my ($bundle, $exp) = @_;
  # ignore any after-release plugins at the end
  my @after = qw(
    Git::
    InstallRelease
  );
  my $skip = qr/^Dist::Zilla::Plugin::(${\join('|', @after)})/;
  # NOTE: just looking for the last plugin in the array is fragile
  my $releaser = (grep { $_->[1] !~ $skip } reverse @{$bundle->plugins})[0];
  like($releaser->[1], qr/\b$exp$/, "expected releaser: $exp");
}
