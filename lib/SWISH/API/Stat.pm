package SWISH::API::Stat;

use strict;
use warnings;

use base qw( SWISH::API::More );
use Carp;
#use Data::Dump qw/dump/;
use Path::Class::File::Stat;

our $VERSION = '0.02';

__PACKAGE__->mk_accessors(
    qw/
      paranoia_level
      paranoia
      /
);

my %paranoia = (

    Search  => 2,
    Results => 3,
    Result  => 4

);

sub init
{
    my $self = shift;

    $self->{paranoia} ||= {%paranoia};
    $self->paranoia_level(1) unless defined $self->paranoia_level;

    $self->{wrappers} ||= {

        'SWISH::API::Stat' => sub {
            my $sam = shift;
            $sam->check_stat(@_);
          }

    };
    
    $self->SUPER::init(@_);


    # new() will create our handle
    # so we just have to stash our stat()s.
    
    my @i;
    for my $f (@{$self->indexes})
    {
        push(@i, Path::Class::File::Stat->new($f));
    }

    $self->indexes(\@i);

}

sub DESTROY
{
    my $self = shift;
    #$self->logger("DESTROYing $self") if $self->log;
}

sub reconnect
{
    my $self = shift;
    $self->logger("re-connecting to swish-e index") if $self->log;
    $self->handle(@{$self->indexes});
}

sub check_stat
{
    my $self  = shift;
    my $reset = 0;
    for my $i (@{$self->indexes})
    {
        #$self->logger("stat'ing $i") if $self->log;
        $reset++ if $i->changed;
    }
    $self->reconnect if $reset;
}

sub New_Search_Object
{

    #Carp::carp "New_Search_Object";
    #Carp::carp Data::Dump::pp(\@_);
    my $so = $_[0]->handle->new_search_object;

    #carp dump $so;
    return $so;
}

sub new_search_object { New_Search_Object(@_) }

1;

package SWISH::API::Stat::Search;

sub Execute_before
{
    my $self = shift;
    $self->check_stat if $self->paranoia->{Search} <= $self->paranoia_level;
    return ();
}

sub execute_before { Execute_before(@_) }

1;


__END__

=head1 NAME

SWISH::API::Stat - automatically reconnect to a SWISH::API handle if index file changes

=head1 SYNOPSIS

  use SWISH::API::Stat;
  my $swish = SWISH::API::Stat->new(
                    log             => $filehandle, 
                    indexes         => [ 'path/to/index' ],
                    paranoia_level  => 1
                    );
                    
  # use just like $swish handle in SWISH::API

=head1 DESCRIPTION

SWISH::API::Stat will detect if the Swish-e index(es) to which you are connected
have been modified and will automatically flush the stale handle and create a new one.

SWISH::API::Stat is most useful in long-running processes where the underlying index
might be merged, renamed or replaced, as in a mod_perl setup.


=head1 METHODS

L<SWISH::API::Stat> is a subclass of L<SWISH::API::More>. See that module's documentation.

=head2 new

Create a new object.

The following key/value pairs are supported:

=over

=item log

A filehandle for printing logger() messages. Set to C<0> to disable logging.
Default is to print re-connect messages to STDERR.

=item indexes

Which index files you want to connect to.

=item paranoia_level( 0|1|2|3|4 )

Sets the level at which an index file will be stat()'d to find out if it has changed.
The default is C<1> which means that every time you access I<$swish> the index will be
stat()'d. This is most useful for when you call new_search_object(), since the time
lapse between one search object and the next is usually small compared to the lifetime
of a long-running process.

It's usually safe to just stay with the default. At most you'll see one query go awry, if
by some chance an index changes in the middle of a query (between the time you call 
new_search_object() and when it is destroyed).
If your indexes change often enough that too many requests are failing due to stale filehandles,
you can bump the B<paranoia_level> up to C<2>, which will stat() the index whenever
a Search object is execute()'d. If your paranoia level is higher than that, you should
be helping the author work on Swish-e version 3, which will have stable incremental
indexing and avoid the stale filehandle issue altogether.

=item paranoia( \%I<class_to_level> )

Get/set the mapping of class names to paranoia_levels. If you really need this, read the source.

=back


=head1 SEE ALSO

L<SWISH::API>, L<SWISH::API::More>, L<Path::Class::File::Stat>


=head1 AUTHOR

Peter Karman, E<lt>karman@cpan.orgE<gt>

Thanks to L<Atomic Learning|http://www.atomiclearning.com/> for supporting some
of the development of this module.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Peter Karman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
