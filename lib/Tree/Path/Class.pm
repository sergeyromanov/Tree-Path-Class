use utf8;
use Modern::Perl;

package Tree::Path::Class;
{
    $Tree::Path::Class::DIST = 'Tree-Path-Class';
}
use strict;

our $VERSION = '0.002';    # VERSION
use Const::Fast;
use English '-no_match_vars';
use Path::Class;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Has::Options;
use MooseX::NonMoose;
use MooseX::Types::Path::Class qw(Dir is_Dir to_Dir File is_File to_File);
use MooseX::MarkAsMethods autoclean => 1;
extends 'Tree';

const my $ERROR => __PACKAGE__ . '::Error';
Moose::Meta::Class->create(
    $ERROR => ( superclasses => ['Throwable::Error'] ) );

# defang Moose's hashref params
around BUILDARGS => sub { &{ $ARG[0] }( $ARG[1] ) };

sub FOREIGNBUILDARGS { return _value_to_path( @ARG[ 1 .. $#ARG ] ) }

has path => (
    qw(:ro :lazy),
    isa => maybe_type( union( [ Dir, File ] ) ),
    init_arg => undef,
    writer   => '_set_path',
    default  => sub { $ARG[0]->_tree_to_path },
);

around set_value => sub {
    my ( $orig, $self ) = splice @ARG, 0, 2;
    $self->$orig( _value_to_path(@ARG) );
    $self->_set_path( $self->_tree_to_path );
    return $self;
};

around add_child => sub {
    my ( $orig, $self ) = splice @ARG, 0, 2;

    my $options_ref;
    if ( ref $ARG[0] eq 'HASH' and not blessed $ARG[0] ) {
        $options_ref = shift;
    }

    my @nodes = @ARG;
    for my $node (@nodes) {
        given ( blessed $node) {
            when (__PACKAGE__) {next}
            when ('Tree') { $node = _tree_to_tpc($node) }
            default {
                $ERROR->throw(
                    'can only add ' . __PACKAGE__ . ' or Tree children' );
            }
        }
    }
    if ($options_ref) { unshift @nodes, $options_ref }
    return $self->$orig(@nodes);
};

sub _tree_to_tpc {
    my $tree = shift;
    my $tpc  = __PACKAGE__->new( $tree->value );
    if ( $tree->meta ) { $tpc->meta( $tree->meta ) }
    for ( $tree->children ) { $tpc->add_child($ARG) }
    return $tpc;
}

after add_child => sub {
    for my $child ( shift->children ) {
        $child->_set_path( $child->_tree_to_path );
    }
};

sub _tree_to_path {
    my $self   = shift;
    my @path   = $self->value;
    my $parent = $self->parent;
    if ( !$parent->isa('Tree::Null') ) {
        unshift @path, $parent->_tree_to_path;
    }
    return _value_to_path(@path);
}

sub _value_to_path {
    return if !@ARG;
    my @args = @ARG;
    for my $arg ( grep {$ARG} @args ) {
        if ( not( is_Dir($arg) or is_File($arg) ) ) {
            $arg = to_Dir($arg) or $ERROR->throw(q{couldn't coerce to a dir});
        }
    }
    return is_File( $args[-1] ) ? to_File( \@args ) : to_Dir( \@args );
}

__PACKAGE__->meta->make_immutable();
no Moose::Util::TypeConstraints;
no Moose;
1;

# ABSTRACT: Tree for Path::Class objects

__END__

=pod

=for :stopwords Mark Gardner GSI Commerce cpan testmatrix url annocpan anno bugtracker rt
cpants kwalitee diff irc mailto metadata placeholders metacpan

=encoding utf8

=head1 NAME

Tree::Path::Class - Tree for Path::Class objects

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use Tree::Path::Class;
    use Path::Class;

    my $tree  = Tree::Path::Class->new( dir('/parent/dir') );
    my $child = Tree::Path::Class->new( file('child/file') );
    $tree->add_child($child);

    print $child->path->stringify;
    # /parent/dir/child/file

=head1 DESCRIPTION

This module subclasses L<Tree|Tree> to only accept
L<Path::Class::Dir|Path::Class::Dir> or L<Path::Class::File|Path::Class::File>
values, and provides a C<path> attribute for retrieving the full path of a tree
branch or leaf.

=head1 ATTRIBUTES

=head2 path

A read-only accessor that returns the tree's full
L<Path::Class::Dir|Path::Class::Dir> or L<Path::Class::File|Path::Class::File>
object, with all parents prepended.

=head1 METHODS

=head2 FOREIGNBUILDARGS

Coerces the parameter passed to C<new()> into a
L<Path::Class::Dir|Path::Class::Dir> or L<Path::Class::File|Path::Class::File>
before passing it on to the superclass constructor.

=head2 add_child

Works just like L<the superclass' method|Tree/add_child>.  Plain L<Tree|Tree>
nodes will be recursively recreated as C<Tree::Path::Class>
nodes when added.

=head1 SUPPORT

=head2 Perldoc

You can find documentation for this module with the perldoc command.

  perldoc Tree::Path::Class

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

Search CPAN

The default CPAN search engine, useful to view POD in HTML format.

L<http://search.cpan.org/dist/Tree-Path-Class>

=item *

AnnoCPAN

The AnnoCPAN is a website that allows community annotations of Perl module documentation.

L<http://annocpan.org/dist/Tree-Path-Class>

=item *

CPAN Ratings

The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

L<http://cpanratings.perl.org/d/Tree-Path-Class>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.perl.org/dist/overview/Tree-Path-Class>

=item *

CPAN Testers

The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/T/Tree-Path-Class>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Tree-Path-Class>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Tree::Path::Class>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the web
interface at L<https://github.com/mjgardner/Tree-Path-Class/issues>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/mjgardner/Tree-Path-Class>

  git clone git://github.com/mjgardner/Tree-Path-Class.git

=head1 AUTHOR

Mark Gardner <mjgardner@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by GSI Commerce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
