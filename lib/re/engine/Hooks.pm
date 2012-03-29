package re::engine::Hooks;

use 5.010001;

use strict;
use warnings;

=head1 NAME

re::engine::Hooks - Hookable variant of the Perl core regular expression engine.

=head1 VERSION

Version 0.01

=cut

our ($VERSION, @ISA);

sub dl_load_flags { 0x01 }

BEGIN {
 $VERSION = '0.01';
 require DynaLoader;
 push @ISA, qw<Regexp DynaLoader>;
 __PACKAGE__->bootstrap($VERSION);
}

=head1 SYNOPSIS

In your XS file :

    #include "re_engine_hooks.h"

    STATIC void dri_comp_hook(pTHX_ regexp *rx, regnode *node) {
     ...
    }

    STATIC void dri_exec_hook(pTHX_ regexp *rx, regnode *node,
                              regmatch_info *info, regmatch_state *state) {
     ...
    }

    MODULE = Devel::Regexp::Instrument    PACKAGE = Devel::Regexp::Instrument

    BOOT:
    {
     reh_register("Devel::Regexp::Instrument", dri_comp_hook, dri_exec_hook);
    }

In your Perl module file :

    package Devel::Regexp::Instrument;

    use strict;
    use warnings;

    our ($VERSION, @ISA);

    use re::engine::Hooks; # Before loading our own shared library

    BEGIN {
     $VERSION = '0.01';
     require DynaLoader;
     push @ISA, 'DynaLoader';
     __PACKAGE__->bootstrap($VERSION);
    }

    sub import   { re::engine::Hooks::enable(__PACKAGE__) }

    sub unimport { re::engine::Hooks::disable(__PACKAGE__) }

    1;

In your F<Makefile.PL>

    use ExtUtils::Depends;

    my $ed = ExtUtils::Depends->new(
     'Devel::Regexp::Instrument' => 're::engine::Hooks',
    );

    WriteMakefile(
     $ed->get_makefile_vars,
     ...
    );

=head1 DESCRIPTION

This module provides a version of the perl regexp engine that can call user-defined XS callbacks at the compilation and at the execution of each regexp node.

=head1 C API

The C API is made available through the F<re_engine_hooks.h> header file.

=head2 C<reh_comp_hook>

The typedef for the regexp compilation phase hook.
Currently evaluates to :

    typedef void (*reh_comp_hook)(pTHX_ regexp *, regnode *);

=head2 C<reh_exec_hook>

The typedef for the regexp execution phase hook.
Currently evaluates to :

    typedef void (*reh_exec_hook)(pTHX_ regexp *, regnode *, regmatch_info *, regmatch_state *);

=head2 C<reh_register>

    void reh_register(pTHX_ const char *key, reh_comp_hook comp, reh_exec_hook exec);

Registers under the given name C<key> a callback C<comp> that will run during the compilation phase and a callback C<exec> that will run during the execution phase.
Null function pointers are allowed in case you don't want to hook one of the phases.
C<key> should match with the argument passed to L</enable> and L</disable> in Perl land.
An exception will be thrown if C<key> has already been used to register callbacks.

=cut

my $RE_ENGINE = _ENGINE();

my $croak = sub {
 require Carp;
 Carp::croak(@_);
};

=head1 PERL API

=head2 C<enable>

    enable $key;

Lexically enables the hooks associated with the key C<$key>

=head2 C<disable>

    disable $key;

Lexically disables the hooks associated with the key C<$key>

=cut

sub enable {
 my ($key) = @_;

 s/^\s+//, s/\s+$// for $key;
 $croak->('Invalid key') if $key =~ /\s/ or not _registered($key);
 $croak->('Another regexp engine is in use') if  $^H{regcomp}
                                             and $^H{regcomp} != $RE_ENGINE;

 $^H |= 0x020000;

 my $hint = $^H{+(__PACKAGE__)} // '';
 $hint = "$key $hint";
 $^H{+(__PACKAGE__)} = $hint;

 $^H{regcomp} = $RE_ENGINE;

 return;
}

sub disable {
 my ($key) = @_;

 s/^\s+//, s/\s+$// for $key;
 $croak->('Invalid key') if $key =~ /\s/ or not _registered($key);

 $^H |= 0x020000;

 my @other_keys = grep !/^\Q$key\E$/, split /\s+/, $^H{+(__PACKAGE__)} // '';
 $^H{+(__PACKAGE__)} = join ' ', @other_keys, '';

 delete $^H{regcomp} if $^H{regcomp} and $^{regcomp} == $RE_ENGINE
                                     and !@other_keys;

 return;
}

=head1 EXAMPLES

See the F<t/re-engine-Hooks-TestDist/> directory in the distribution.
It implements a couple of simple examples.

=head1 DEPENDENCIES

L<perl> 5.10.1.

L<ExtUtils::Depends>.

=head1 SEE ALSO

L<perlreguts>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-re-engine-hooks at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=re-engine-Hooks>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command :

    perldoc re::engine::Hooks

=head1 COPYRIGHT & LICENSE

Copyright 2012 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
