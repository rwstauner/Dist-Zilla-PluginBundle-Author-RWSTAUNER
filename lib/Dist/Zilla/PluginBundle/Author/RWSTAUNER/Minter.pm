# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;

package Dist::Zilla::PluginBundle::Author::RWSTAUNER::Minter;
# ABSTRACT: RWSTAUNER's Dist::Zilla config for minting

use Moose;
use MooseX::AttributeShortcuts;
use Git::Wrapper;
use Data::Section -setup;

with qw(
  Dist::Zilla::Role::PluginBundle::Easy
);

has pause_id => (
  is         => 'ro',
  default    => sub { ((ref($_[0]) || $_[0]) =~ /Author::([A-Z]+)/)[0] },
);

has _git => (
  is         => 'lazy',
  default    => sub { Git::Wrapper->new('.') },
);

sub git_config {
  my ($self, $key) = @_;
  return ($self->_git->config($key))[0];
}

foreach my $attr ( qw( name email ) ){
  has "git_$attr" => (
    is         => 'lazy',
    default    => sub { $_[0]->git_config("user.$attr") },
  );
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
    [ TemplateModule => ':DefaultModuleMaker', { template => 'Module.template' } ],

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

  $self->generate_files( $self->merged_section_data );
  $self->generate_mailmap;
}

sub generate_files {
  my ($self, $files) = @_;
  while( my ($name, $content) = each %$files ){
    $content = $$content;
    # GenerateFile will append a new line
    $content =~ s/\n+\z//;
    $self->add_plugins(
      [
        GenerateFile => "Generate-$name" => {
          filename    => $name,
          is_template => 1,
          content     => $content,
        }
      ],
    );
  }
}

sub generate_mailmap {
  my ($self) = @_;
  $self->generate_files({
    '.mailmap' => \sprintf '%s <%s@cpan.org> <%s>',
      $self->git_name, lc($self->pause_id), $self->git_email,
  });
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=for Pod::Coverage configure
git_config
generate_files
generate_mailmap

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

__DATA__
__[ .gitignore ]__
/{{$dist->name}}*
/.build
/cover_db/
/nytprof*
/tags
__[ dist.ini ]__
{{
  $license = ref $dist->license;
  if ( $license =~ /^Software::License::(.+)$/ ) {
    $license = $1;
  } else {
    $license = "=$license";
  }

  $authors = join( "\n", map { "author   = $_" } @{ $dist->authors } );
  $copyright_year = (localtime)[5] + 1900;
  '';
}}name     = {{ $dist->name }}
{{ $authors }}
license  = {{ $license }}
copyright_holder = {{ join( ', ', map { (/^(.+) <.+>/)[0] }@{ $dist->authors } ) }}
copyright_year   = {{ $copyright_year }}

[@Author::RWSTAUNER]
__[ Changes ]__
Revision history for {{$dist->name}}

{{ '{{$NEXT}}' }}

  - Initial release
__[ README.pod ]__
{{'='}}head1 NAME

{{ (my $n = $dist->name) =~ s/-/::/g; $n }} - undef

{{'='}}head1 COPYRIGHT AND LICENSE

This software is copyright (c) {{ (localtime)[5]+1900 }} by {{ $dist->copyright_holder }}.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

{{'='}}cut
