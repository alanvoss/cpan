package AnyEvent::NamedDependency;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        dependencies => {}
    }, ref $class || $class;
}

sub add {
    my ($self, %args) = @_;
    # name, callback, waitfordependency

    # need to start a loop of some sort for when nothing else is waiting
    # possibly go ahead and check _next_dependency, in case that one's done
    # call start immediately if no waitfordependency is passed?
}

sub start {
    # returns the waiting variable
}

sub clear {
    # clear everything if no arg passed
    # clear specific dependecies, if array of dependency names is passed
}

sub _next_dependency {
    my ($self, $name) = @_;
    # check for anything waiting for $name
    # check that nothing else is currently waiting on name
    # execute, if so
    # check that there is nothing else to do at all, and ->send
}

1;
