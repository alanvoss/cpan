package Statistics::WeightedSelection;

use Modern::Perl;
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

=head2 add(object, weight)

Adds an object (any perl scalar will do) with an associated numeric weight.
Decimal values are allowed.

=head2 get_random

Get a random weighted item and remove it from the future selection pool for the
next get_random() call.

=head1 EXAMPLES

=head1 FILES

=head1 SEE ALSO

=head1 CAVEATS

=head1 AUTHOR

Alan Voss <avoss@rent.com>

=cut
