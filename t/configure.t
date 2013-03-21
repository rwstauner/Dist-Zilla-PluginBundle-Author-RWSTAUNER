# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
use Test::More 0.96;
use lib 't/lib';
use Test::DZil;

my $NAME = 'Author::RWSTAUNER';
my $BNAME = "\@$NAME";
my $mod = "Dist::Zilla::PluginBundle::$NAME";
eval "require $mod" or die $@;

# shh...
local $SIG{__WARN__} = sub { warn(@_) unless $_[0] =~ /^\[$BNAME\].+Including builders:/ };

# get default MetaNoIndex hashref
my $noindex = (
  grep { ref($_) && $_->[0] =~ 'MetaNoIndex' }
      @{ init_bundle()->plugins }
)[0]->[-1];
delete $noindex->{':version'}; # but ignore this

my $noindex_dirs = $noindex->{directory};

# test attributes that change plugin configurations
my %default_exp = (
  'Test::Compile'         => {fake_home => 1},
  PodWeaver               => {config_plugin => $BNAME},
  AutoPrereqs             => {},
  MetaNoIndex             => {%$noindex, directory => [@$noindex_dirs]},
  'MetaProvides::Package' => {meta_noindex => 1},
  Authority               => {do_metadata => 1, do_munging => 1, locate_comment => 0},
  PruneDevelCoverDatabase => { match => '^(cover_db/.+)' },
);

foreach my $test (
  [{}, {%default_exp}],
  [{'placeholder_comments' => 1   },            { %default_exp, Authority => {do_metadata => 1, do_munging => 1, locate_comment => 1} }],
  [{'PruneFiles.match' => 'fudge'},             { %default_exp, map { ("Prune$_" => {match => 'fudge'}) } qw(CodeStatCollection DevelCoverDatabase) }],
  [{'PruneDevelCoverDatabase.match' => 'fudge'}, { %default_exp, PruneDevelCoverDatabase => {match => 'fudge'} }],
  [{'AutoPrereqs.skip' => 'Goober'},            { %default_exp, AutoPrereqs => {skip => 'Goober'} }],
  [{'MetaNoIndex.directory'  => 'goober'},      { %default_exp, MetaNoIndex => {%$noindex, directory => [@$noindex_dirs, 'goober']} }],
  #[{'MetaNoIndex.directory@' => 'goober'},      { %default_exp, MetaNoIndex => {%$noindex, directory => ['goober']} }],
  [{'Test::Compile.fake_home' => 0},            { %default_exp, 'Test::Compile' => {fake_home => 0} }],
  [{'Test::Portability.options' => 'test_one_dot=0'}, { %default_exp, 'Test::Portability' => {options => 'test_one_dot=0'} }],
  [{'MetaProvides::Package.meta_noindex' => 0}, { %default_exp, 'MetaProvides::Package' => {meta_noindex => 0} }],
  [{weaver_config => '@Default', 'MetaNoIndex.directory[]' => 'arr'}, {
    PodWeaver => {config_plugin => '@Default'},
    MetaNoIndex => {%$noindex, directory => [@$noindex_dirs, 'arr']} }],
){
  my ($config, $exp) = @$test;
  my $checked = {};

  my @plugins = @{init_bundle($config)->plugins};

  foreach my $plugin ( @plugins ){
    my ($moniker, $name, $payload) = @$plugin;
    my ($plugname) = ($moniker =~ m#([^/]+)$#);

    my $matched = exists $exp->{$plugname} ? $plugname : exists $exp->{$name} ? $name : next;
    if( exists $exp->{$matched} ){
      delete $payload->{':version'}; # ignore any versions in comparison
      is_deeply($payload, $exp->{$matched}, "expected configuration for $matched")
        or diag explain [$payload, $matched, $exp->{$matched}];
      ++$checked->{$matched};
    }
  }
  is_deeply { map { $_ => 1 } keys %$exp }, $checked, 'not all tests ran';
}

# test attributes that alter which plugins are included
{
  my $bundle = init_bundle({});
  my $test_name = 'expected plugins included';

  my $has_ok = sub {
    ok( has_plugin($bundle, @_), "expected plugin included: $_[0]");
  };
  my $has_not = sub {
    ok(!has_plugin($bundle, @_), "plugin expectedly not found: $_[0]");
  };
  &$has_ok('PodWeaver');
  &$has_ok('PodWeaver');
  &$has_ok('AutoPrereqs');
  &$has_ok('Test::Compile');
  &$has_ok('CheckExtraTests');
  &$has_not('FakeRelease');
  &$has_ok('UploadToCPAN');
  &$has_ok('Test::Compile');
  &$has_ok('PkgVersion');

  $bundle = init_bundle({placeholder_comments => 1});
  &$has_ok('OurPkgVersion');
  &$has_not('PkgVersion');

  $bundle = init_bundle({auto_prereqs => 0});
  &$has_not('AutoPrereqs');

  $bundle = init_bundle({fake_release => 1});
  &$has_ok('FakeRelease');
  &$has_not('UploadToCPAN');

  $bundle = init_bundle({is_task => 1});
  &$has_ok('TaskWeaver');
  &$has_not('PodWeaver');

  $bundle = init_bundle({releaser => 'Goober'});
  &$has_ok('Goober');
  &$has_not('UploadToCPAN');

  $bundle = init_bundle({skip_plugins => '\b(Test::Compile|ExtraTests|GenerateManifestSkip)$'});
  &$has_not('Test::Compile');
  &$has_not('ExtraTests');
  &$has_not('GenerateManifestSkip', 1);

  $bundle = init_bundle({'-remove' => [qw(Test::Compile ExtraTests)]});
  &$has_not('Test::Compile');
  &$has_not('ExtraTests');
  &$has_ok('NoTabsTests');

  $bundle = init_bundle({});
  &$has_ok('MakeMaker');
  &$has_not('ModuleBuild');
  &$has_not('DualBuilders');
  $bundle = init_bundle({builder => 'mb'});
  &$has_ok('ModuleBuild');
  &$has_not('MakeMaker');
  &$has_not('DualBuilders');
  $bundle = init_bundle({builder => 'both'});
  &$has_ok('MakeMaker');
  &$has_ok('ModuleBuild');
  &$has_ok('DualBuilders');
}

# test releaser
foreach my $releaser (
  [{},                                        'UploadToCPAN'],
  [{fake_release => 1},                       'FakeRelease'],
  [{releaser => ''},                           undef],
  [{releaser => 'No_Op_Releaser'},            'No_Op_Releaser'],
  # fake_release wins
  [{releaser => 'No_Op_Releaser', fake_release => 1}, 'FakeRelease'],
){
  my ($config, $exp) = @$releaser;
  releaser_is(new_dzil($config), $exp);
  # env always overrides
  local $ENV{DZIL_FAKERELEASE} = 1;
  releaser_is(new_dzil($config), 'FakeRelease');
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
sub new_dzil {
  return Builder->from_config(
    { dist_root => 'corpus' },
    { add_files => {
        'source/dist.ini' => simple_ini([$BNAME => @_]),
      }
    },
  );
}
sub init_bundle {
  # compatible with non-easy bundles
  my @plugins = $mod->bundle_config({name => $BNAME, payload => $_[0] || {}});
  # return object with ->plugins method for convenience/sanity
  my $bundle = $mod->new(name => $BNAME, payload => $_[0] || {}, plugins => \@plugins);
  isa_ok($bundle, $mod);
  return $bundle;
}
sub releaser_is {
  my ($dzil, $exp) = @_;
  my @releasers = @{ $dzil->plugins_with(-Releaser) };

  if( !defined($exp) ){
    is(scalar @releasers, 0, 'no releaser');
  }
  else {
    is(scalar @releasers, 1, 'single releaser');
    like($releasers[0]->plugin_name, qr/\b$exp$/, "expected releaser: $exp");
  }
}
