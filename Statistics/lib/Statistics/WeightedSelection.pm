package Statistics::WeightedSelection;

use strict;
use warnings;

use Storable qw/freeze/;

our $VERSION = 0.01;

sub new {
    my ($class, %args) = @_;

    return bless {
        objects          => [],
        id_lookup        => {},
        with_replacement => $args{with_replacement} || 0,
    }, $class;
}

sub add {
    my ($self, %args) = @_;

    # a non-zero number which can include a decimal
    my $weight = $args{weight};

    # the scalar item that becomes a candidate for random selection
    my $object = $args{object};

    # an optional id, which can be used for later removal from pool
    my $id = $args{id} // (ref $object ? freeze($object) : $object);

    unless ($weight && $object) {
        die 'Calls to ' . __PACKAGE__ . "::add() must include an arg named 'object'"
            . " and a non-zero weight\n";
    }

    unless ($weight =~ /^\d+(\.\d*)?/) {
        die 'Calls to ' . __PACKAGE__ . "::add()'s must include an arg named 'weight'"
            . " that must be a whole integer or number with decimal\n";
    }

    # in order to derive the starting_index (see the next stanza),
    # we need the last item in @$self
    my $last = $self->_get_last;

    # develops a structure that looks like the following, with each element being
    # [
    #     {
    #         starting_index => 0,
    #         length         => 40,
    #         object         => 'apple',
    #         id             => 'gwr3723',
    #     },
    #     {
    #         starting_index => 40,
    #         length         => 16,
    #         object         => 'plum',
    #         id             => 'avx9716',
    #     },
    #     {
    #         starting_index => 56,
    #         length         => 3.4
    #         object         => 'peach',
    #         id             => 'zzi1250',
    #     },
    #     {
    #         starting_index => 59.4,
    #         length         => 60,
    #         object         => 'mango',
    #         id             => 'umn2932',
    #     },
    # ]

    push @{$self->{objects}}, {
        starting_index => defined $last ? $last->{starting_index} + $last->{weight} : 0,
        weight         => $weight,
        object         => $object,
        id             => $id,
    };

    $self->{id_lookup}->{$id}->{$#{$self->{objects}}} = undef;

    return $#{$self->{objects}};
}

sub remove {
    my ($self, $id) = @_;

    unless (defined $id) {
        die 'Calls to ' . __PACKAGE__ . "::remove() must include an id to remove\n";
    }

    $id = ref $id ? freeze($id) : $id;

    my $indexes = delete $self->{id_lookup}->{$id};

    unless ($indexes && %{$indexes}) {
        warn "Key $id contains no associated indexes currently\n";
        return;
    }

    my @reverse_sorted_indexes = sort {$b <=> $a} keys %{$indexes};

    my @removed;
    for my $index (@reverse_sorted_indexes) {
        push @removed, splice(@{$self->{objects}}, $index, 1);
    }

    $self->_consolidate(reverse @reverse_sorted_indexes);

    return map {$_->{object}} @removed;
}

sub get_object {
    my ($self, $override_replacement) = @_;
    return unless @{ $self->{objects} };

    # when adding the starting_index and length together of the last item in @$self,
    #    (see the generated structure note in the add() method for more info), the
    #    max random number to generate is determined.
    my $last = $self->_get_last;
    my $random = rand($last->{starting_index} + $last->{weight});

    # binary search to quickly find the weighted index range.  the random number ($random)
    # is tested against the range of starting_index and (starting_index + length) to
    # determine if the number is lower or higher than the current arrayref until a match
    # is found.
    my $max = $#{ $self->{objects} };
    my $min = 0;
    my $index = 0;
    while ( $max >= $min ) {
        $index = int( ( $max + $min ) / 2 );
        my $current_object = $self->{objects}->[$index];

        if ( $random < $current_object->{starting_index} ) {
            $max = $index - 1;
        }
        elsif ( $random >= ($current_object->{starting_index} + $current_object->{weight}) ) {
            $min = $index + 1;
        }
        else {
            last;
        }
    }

    my $random_element;
    if ($self->replace_object) {
        $random_element = $self->{objects}->[$index];
    }
    else {
        # remove the element in question
        $random_element = splice(@{$self->{objects}}, $index, 1);

        delete $self->{id_lookup}->{$random_element->{id}}->{$index};
        unless (keys %{$self->{id_lookup}->{$random_element->{id}}}) {
            delete $self->{id_lookup}->{$random_element->{id}};
        }
    
        $self->_consolidate($index);
    }

    return $random_element->{object};
}

sub replace_object {
    my ($self) = @_;
    return $self->{with_replacement};
}

sub clear {
    my ($self) = @_;
    $self->{objects} = [];
    $self->{id_lookup} = {};
    return;
}

sub count {
    my ($self) = @_;
    return 0 if !@{ $self->{objects} };
    return $#{ $self->{objects} } + 1;
}

sub _consolidate {
    my $self = shift;

    # drop all indexes greater than the current length
    my @removed_indexes = sort grep {$_ <= $#{ $self->{objects} }} @_;

    for my $removed_index_index (0..$#removed_indexes) {
        my $range_start = $removed_indexes[$removed_index_index];
        my $range_end   = $removed_index_index == $#removed_indexes
            ? $#{ $self->{objects} }
            : $removed_indexes[$removed_index_index + 1] - 1;
        my $to_subtract = @removed_indexes - $removed_index_index;
        my %ids_evaluated_for_range;
        for my $object_index ($range_start..$range_end) {
            my $object = $self->{objects}->[$object_index];
            if (!$ids_evaluated_for_range{$object->{id}}++) {
                for my $index (
                    grep {$_ >= $range_start && ($removed_index_index == $#removed_indexes || $_ <= $range_end)}
                    keys %{$self->{id_lookup}->{$object->{id}}}
                ) {
                    delete $self->{id_lookup}->{$object->{id}}->{$index};
                    $self->{id_lookup}->{$object->{id}}->{$index - $to_subtract} = undef;
                }
            }

            $object->{starting_index} = $object_index == 0
                ? 0
                : do {
                      my $previous_object = $self->{objects}->[$object_index - 1];
                      $previous_object->{starting_index} + $previous_object->{weight};
                  };
        }
    }

    return;
}


# simply a utility method to get the last item in the blessed array, as it contains all
# the information needed to add items and generate a random number.
sub _get_last {
    my ($self) = @_;
    return unless @{ $self->{objects} };
    return $self->{objects}->[$#{ $self->{objects} }];
}

1;

__END__

=pod

=head1 NAME

Statistics::WeightedSelection - Select a random object according to its weight.

=head1 VERSION

version 0.01

=head1 SYNOPSIS

    use Statistics::WeightedSelection;

    my $w = Statistics::WeightedSelection->new();

    # add some objects
    $w->add(
        object => 'string',
        weight => 4,
    );
    $w->add(
        object => {p => 1, q => 2},
        weight => 1,
    );
    $w->add(
        object => $any_scalar,
        weight => 7.5,
    );

    # get a random one based upon the individual weight relative to the
    #   combined weight and remove it from the pool for future selection
    #
    #   4 / 12.5 * 100 percent of the time, you'll get 'string'
    #   1 / 12.5 * 100 percent of the time, you'll get {p => 1, q => 2}
    # 7.5 / 12.5 * 100 percent of the time, you'll get $any_scalar
    my $object = $w->get_object();

    # because the last one was removed, the remaining objects are the new
    #   pool for calculating weights and probabilities
    my $another_object = $w->get_object();

    # get the number of objects remaining
    my $remaining_object_count = $w->count();

    # when constructed using with_replacement and a true value, probababilities
    #   of being selected will remain constant, as after an item is selected,
    #   it is not removed from the pool.
    my $wr = Statistics::WeightedSelection->new(with_replacement => 1);
    #...
    #...
    my $replaced_object = $wr->get_object();

=head1 DESCRIPTION

A WeightedSelection object is intended to hold unordered objects that each
have a corresponding weight.  The objects can be any perl scalar or object,
and the weights can be any positive integer or floating number.

At any time, an object can be retrived from the pool.  The probability of
any object being selected corresponds to its weight divided by the combined
weight of all the objects currently in the container.

Objects that are no longer desired to be in the pool can be removed, and
an id can be assigned to any of the items to ease in this later removal.

=head1 METHODS


=head2 CONSTRUCTOR (new)

To create a new cache object, call C<<Statistics::WeightedSelection-E<gt>new>.
It takes the optional arguments listed below.

=over

=item with_replacement (optional)

This single configuration, when true, will not remove the object selected
from the pool after a call to get_object();

    # replace the object selected with the same object, i.e. don't remove it.
    my $w = Statistics::WeightedSelection->new(with_replacement => 1);

=back

=head2 add

This method is used to add an object and weight to the objects for possible
future selection.  2 required and 1 optional arg are described below.

=over

=item object (required)

The object.  Any scalar will do: string, arrayref, hashref, blessed scalar
or otherwise.

=item weight (required)

The weight.  Integer or float/decimal.  Must be greater than 0.  This arbitrary
number when divided by the total combined weights of the object is the probability
that it will be selected on the next call to get_object();

=item id (optional)

This is an id that can be used to remove() items later, if desired.  It is not
required, and the value, if not passed, will default to a serialized version
of the object passed (see above).

=back

=head2 get_object

Selects an object from the bucket / pool / container randomly, with probabilities
of being picked for each item equal to its weight divided by the combined weights.

By default, the object is removed without replacement.  If with_replacement was
passed to the constructor, or if in a subclass, a call to replace_object() returns
true, then the object is not deleted, and is effectively replaced (or put back) into
the pool for future selection.

Takes no arguments.

=head2 remove

Items that were previously added using add() can be removed from future selection.
Either objects that are equivalent (not necessarily a ref to the same object in the
container, but one that after serialization is equivalent), or ones that match an id
(which was an optional arg for add()) will all be removed.

=head2 clear

Removes all items from the selection pool.  A call to get_object() immediately afterward
will return nothing.

=head2 count

The current count of objects that are in the selection pool.  It should be noted that
sometimes, the same scalar might have been added multiple times with calls to add(), and
that those separate instances are all counted separately.

=head2 replace_object

Returns whether or not a future call to get_object will replace the object (i.e. not remove
it).  If true, the object will not be removed.  If false, the object will be removed.

The default behavior, if nothing was passed to the constructor, is to have this return false.

In a subclass, this method could be overwritten for behavior that doesn't always or never
replace the object after a call to get_object().

=head1 ACKNOWLEDGEMENTS

The ideas encapsulated in this module were created while I was working at Rent.com, a
RentPath company.  Rent.com has supported me the whole way in releasing this module, and
they have fostered an openness in not only utilizing open community tools, but contributing
to them, as well.

I'd also like to thank a few individuals for their contributions:

=over

=item YAPC 2014 in Orlando, Florida

The conference that finally pushed me to finish this module and make it available.

=item Ripta Pasay

My manager (and brilliant developer) at Rent, who helped ask the appropriate management
at our company about releasing this module without specific, formal policies.

=item Aran Daltec

Former Rent.com employee who helped by allowing me to bounce ideas for names and interface
of this module, and also to help me search for modules that might have already been written
to accomplish a similar purpose.

=item Steve Nolte

Head hauncho of Milwaukee PM who helped steer me in the direction of how to package and
manage this module for release.

=item Steven Lembark

For discussing namespaces and name ideas with a total stranger.  He really is a testament
to how helpful people in the Perl community can be.

=item Sawyer X

More discussion of namespaces, and helping to guide me in to whom to talk about such things
for further ideas.

=item Adam Dutko

For giving a talk at YAPC to discuss issues about making a module and getting it ready for
release on CPAN.

=back

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 AUTHOR

Alan Voss <alanvoss@hotmail.com>

=cut
