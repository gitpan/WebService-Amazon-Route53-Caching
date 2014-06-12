
=head1 NAME

WebService::Amazon::Route53::Caching - Caching layer for the Amazon Route 53 API

=head1 SYNOPSIS

WebService::Amazon::Route53::Caching provides an caching layer on top of
the existing L<WebService::Amazon::Route53> module, which presents an interface
to the Amazon Route 53 DNS service.

=cut

=head1 DESCRIPTION

This module overrides the base behaviour of the L<WebService::Amazon::Route53>
object to provide two specific speedups:

=over 8

=item We force the use of HTTP Keep-Alive when accessing the remote Amazon API end-point.

=item We cache the mapping between zones and Amazon IDs

=back

The reason for the existance of this module was observed performance
issues with the native client.  A user of the Route53 API wishes to use
the various object methods against B<zones>, but the Amazon API requires
that you use their internal IDs.

For example rather than working with a zone such as "steve.org.uk", you
must pass in a zone_id of the form "123ZONEID".  Discovering the ID
of a zone is possible via L<get_hosted_zone|WebService::Amazon::Route53/"get_hosted_zone"> method.

Unfortunately the implementation of the B<get_hosted_zone> method essentially
boils down to fetching all possible zones, and then performing a string
comparison on their names.

This module was born to cache the ID-data of individual zones, allowing
significant speedups when dealing with a number of zones.

=cut

=head1 CACHING

Caching uses the L<DB_File> which provides a fast hash lookup,
using the B<cache> argument passed to the constructor.

All other APIs remain the same.

=cut


package WebService::Amazon::Route53::Caching;

use base ("WebService::Amazon::Route53");
use Carp;

use JSON;
use DB_File;
our $VERSION = "0.1";

=begin doc

Override the constructor to enable Keep-Alive in the UserAgent
object.  This cuts down request time by 50%.

=end doc

=cut

sub new
{
    my ( $class, %args ) = (@_);

    # Invoke the superclass.
    my $self = $class->SUPER::new(%args);

    # Store the cache-file if we've been given a name.
    $self->{ '_cache' } = $args{ 'cache' };

    # Update the User-Agent to use Keep-ALive.
    $self->{ 'ua' } = LWP::UserAgent->new( keep_alive => 10 );

    return $self;
}


=begin doc

Internal method to lookup the value of a key in our cache-file.

=end doc

=cut

sub _cache_get
{
    my ( $self, $key ) = (@_);

    return unless ( $self->{ '_cache' } );

    my %h;
    tie %h, "DB_File", $self->{ '_cache' }, O_RDWRD | O_CREAT, 0666, $DB_HASH or
      return;

    my $ret = $h{ $key };
    untie(%h);

    return ($ret);
}


=begin doc

Internal method to store a value in our internal cache-file.

=end doc

=cut

sub _cache_set
{
    my ( $self, $key, $val ) = (@_);

    return unless ( $self->{ '_cache' } );

    my %h;
    tie %h, "DB_File", $self->{ '_cache' }, O_RDWRD | O_CREAT, 0666, $DB_HASH or
      return;

    $h{ $key } = $val;
    untie(%h);
}



=begin doc

Find data about the hosted zone, preferring our local cache first.

=end doc

=cut

sub find_hosted_zone
{
    my ( $self, %args ) = (@_);

    if ( !defined $args{ 'name' } )
    {
        carp "Required parameter 'name' is not defined";
    }

    #
    #  Lookup from the cache - deserializing after the fetch.
    #
    my $data = $self->_cache_get( "zone_data_" . $args{ 'name' } );
    if ( $data && length($data) )
    {
        my $obj = from_json($data);
        return ($obj);
    }

    #
    # OK that failed, so revert to using our superclass.
    #
    my $result = $self->SUPER::find_hosted_zone(%args);

    #
    # Store the result in our cache so that the next time we'll get a hit.
    #
    $self->_cache_set( "zone_data_" . $args{ 'name' }, to_json($result) );

    return ($result);
}


=begin doc

When a zone is created the Amazon ID is returned, so we can pre-emptively
cache that.

=end doc

=cut

sub create_hosted_zone
{
    my ( $self, %args ) = @_;

    my $result = $self->SUPER::create_hosted_zone(%args);

    if ( result && $result->{ 'zone' } )
    {
        $self->_cache_set( "zone_data_" . $args{ 'name' }, to_json($result) );
    }

    return ($result);
}


=begin doc

When a zone is deleted we'll remove the association we have between
the name and the ID.

=end doc

=cut

sub delete_hosted_zone
{
    my ( $self, %args ) = (@_);

    $self->_cache_set( "zone_data_" . $args{ 'name' }, undef );

    return ( $self->SUPER::delete_hosted_zone(%args) );
}

1;
