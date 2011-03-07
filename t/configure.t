use strict;
use warnings;
use Test::More 0.96;

my $NAME = 'GopherRepellent';
my $BNAME = "\@$NAME";
my $mod = "Dist::Zilla::PluginBundle::$NAME";
eval "require $mod" or die $@;

# get default MetaNoIndex directory arrayref
my $noindex = (grep { ref($_) && $_->[0] eq 'MetaNoIndex' }
	init_bundle({})->_bundled_plugins)[0]->[1]->{directory};

# test attributes that change plugin configurations
my %default_exp = (
	CompileTests            => {fake_home => 1},
	PodWeaver               => {config_plugin => $BNAME},
	AutoPrereqs             => {},
	MetaNoIndex             => {directory => [@$noindex]},
	'MetaProvides::Package' => {meta_noindex => 1},
);

foreach my $test (
	[{}, {%default_exp}],
	[{'skip_prereqs'     => 'Goober'},            { %default_exp, AutoPrereqs => {skip => 'Goober'} }],
	[{'AutoPrereqs:skip' => 'Goober'},            { %default_exp, AutoPrereqs => {skip => 'Goober'} }],
	[{'MetaNoIndex:directory'  => 'goober'},      { %default_exp, MetaNoIndex => {directory => [@$noindex, 'goober']} }],
	[{'MetaNoIndex:directory@' => 'goober'},      { %default_exp, MetaNoIndex => {directory => ['goober']} }],
	[{'CompileTests->fake_home' => 0},            { %default_exp, CompileTests => {fake_home => 0} }],
	[{'MetaProvides::Package:meta_noindex' => 0}, { %default_exp, 'MetaProvides::Package' => {meta_noindex => 0} }],
	[{weaver_config => '@Default', 'MetaNoIndex:directory[]' => 'arr'}, {
		PodWeaver => {config_plugin => '@Default'},
		MetaNoIndex => {directory => ['arr']} }],
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

	$bundle = init_bundle({auto_prereqs => 0});
	ok(!has_plugin($bundle, 'AutoPrereqs'),  $test_name);

	$bundle = init_bundle({fake_release => 1});
	ok( has_plugin($bundle, 'FakeRelease'),  $test_name);
	ok(!has_plugin($bundle, 'UploadToCPAN'), $test_name);

	$bundle = init_bundle({is_task => 1});
	ok( has_plugin($bundle, 'TaskWeaver'),   $test_name);
	ok(!has_plugin($bundle, 'PodWeaver'),    $test_name);

	SKIP: {
		eval 'require Dist::Zilla::Plugin::PodLinkTests';
		skip 'PodLinkTests required for testing pod_link_tests attribute', 1
			if $@;

		$bundle = init_bundle({pod_link_tests => 1});
		ok( has_plugin($bundle, 'PodLinkTests'), $test_name);
	}

		$bundle = init_bundle({pod_link_tests => 0});
		ok(!has_plugin($bundle, 'PodLinkTests'), $test_name);

	$bundle = init_bundle({releaser => 'Goober'});
	ok( has_plugin($bundle, 'Goober'),       $test_name);
	ok(!has_plugin($bundle, 'UploadToCPAN'), $test_name);

	$bundle = init_bundle({skip_plugins => 'CompileTests|ExtraTests'});
	ok(!has_plugin($bundle, 'CompileTests'), $test_name);
	ok(!has_plugin($bundle, 'ExtraTests'),   $test_name);
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
	my ($bundle, $plug) = @_;
	scalar grep { $_->[0] =~ /^$BNAME\/($plug)$/ } @{$bundle->plugins};
}
sub init_bundle {
	my $bundle = $mod->new(name => $BNAME, payload => $_[0]);
	isa_ok($bundle, $mod);
	$bundle->configure;
	return $bundle;
}
sub releaser_is {
	my ($bundle, $exp) = @_;
	# NOTE: just looking for the last plugin in the array is fragile
	like((@{$bundle->plugins})[-1]->[1], qr/\b$exp$/, "expected releaser: $exp");
}
