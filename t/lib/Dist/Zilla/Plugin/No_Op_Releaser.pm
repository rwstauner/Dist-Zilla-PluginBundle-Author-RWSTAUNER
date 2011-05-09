# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
use strict;
use warnings;
package Dist::Zilla::Plugin::No_Op_Releaser;
# ABSTRACT: Release by doing nothing (no-op)

use Moose;

with qw(
  Dist::Zilla::Role::Plugin
  Dist::Zilla::Role::Releaser
);

sub release {
  shift->log('Not releasing anything.  La la la...');
}

1;

=head1 DESCRIPTION

none.

=cut
