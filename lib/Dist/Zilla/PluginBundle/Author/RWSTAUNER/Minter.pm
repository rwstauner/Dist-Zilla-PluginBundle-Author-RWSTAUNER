# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;

package Dist::Zilla::PluginBundle::Author::RWSTAUNER::Minter;
# ABSTRACT: RWSTAUNER's Dist::Zilla config for minting

use Moose;
use MooseX::AttributeShortcuts;
use Git::Wrapper;

with qw(
  Dist::Zilla::Role::PluginBundle::Easy
);

has _git => (
  is         => 'lazy',
  default    => sub { Git::Wrapper->new('.') },
);

sub git_config {
  my ($self, $key) = @_;
  return ($self->_git->config($key))[0];
}

has github_user => (
  is         => 'lazy',
  default    => sub { $_[0]->git_config("github.user") },
);

around bundle_config => sub {
  my ($orig, $self, @args) = @_;
  my @plugins = $self->$orig(@args);

  # remove bundle prefix since dzil looks this one up by name
  $_->[0] =~ s/.+?\/(:DefaultModuleMaker)/$1/ for @plugins;

  return @plugins;
};

sub configure {
  my ($self) = @_;

  $self->add_plugins(
    [ TemplateModule => ':DefaultModuleMaker', { template => 'Module.pm' } ],

    [
      'Git::Init' => $self->github_user ? {
        remote => 'origin git@github.com:' . $self->github_user . '/%N.git',
        config => [
          'branch.master.remote origin',
          'branch.master.merge  refs/heads/master',
        ],
      } : {}
    ],

    #'GitHub::Create',

    [
      'Run::AfterMint' => {
        run => [
          # create the t/ directory so that it's already there
          # when i try to create a file beneath
          '%x -e "mkdir(shift(@ARGV))" %d%pt',
        ],
      },
    ],
  );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=for Pod::Coverage configure
git_config

=head1 SYNOPSIS

  ; profile.ini

  [@Author::RWSTAUNER::Minter]

=head1 DESCRIPTION

Configure L<Dist::Zilla> to mint a new dist.

=head1 ROUGHLY EQUIVALENT

This bundle is roughly equivalent to the following (generated) F<profile.ini>:

=bundle_ini_string

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::MintingProfile::Author::RWSTAUNER>
* L<Dist::Zilla::Role::PluginBundle::Easy>

=cut
