

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
        object => [1, 2, 3],
        weight => 7.5,
    );

use Data::Dumper;
print Dumper $w->get_object();
print Dumper $w->get_object();
print Dumper $w->get_object();
print $w->count . " is the count\n";
