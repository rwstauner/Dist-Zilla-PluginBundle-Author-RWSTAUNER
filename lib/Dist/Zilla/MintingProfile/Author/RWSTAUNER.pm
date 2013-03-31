use strict;
use warnings;

package Dist::Zilla::MintingProfile::Author::RWSTAUNER;
# ABSTRACT: Mint a new dist for RWSTAUNER

use Moose;
with 'Dist::Zilla::Role::MintingProfile::ShareDir';

1;

=head1 SYNOPSIS

  dzil new -P Author::RWSTAUNER

=head1 DESCRIPTION

Profile for minting a new dist with L<Dist::Zilla>.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::App::Command::new>
* L<Dist::Zilla::Role::MintingProfile>

=cut
