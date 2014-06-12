
use strict;
use warnings;

package WebService::Amazon::Route53::Caching::Store::NOP;


=begin doc

Constructor.  Do nothing.

=end doc

=cut

sub new
{
    my ( $proto, %supplied ) = (@_);
    my $class = ref($proto) || $proto;

    my $self = {};

    bless( $self, $class );
    return $self;
}



=begin doc

Do nothing.

=end doc

=cut

sub set
{
    my ( $self, $key, $val ) = (@_);
}



=begin doc

Do nothing.

=end doc

=cut

sub get
{
    my ( $self, $key ) = (@_);

    undef;
}



=begin doc

Do nothing.

=end doc

=cut

sub del
{
    my ( $self, $key ) = (@_);
}



1;