#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 812;
use Storable qw(dclone);

BEGIN {
    my $module = 'Statistics::WeightedSelection';
    use_ok($module, '0.01');
    can_ok($module, 'new');
}

my $check_distribution_count = 10000;

my $w = Statistics::WeightedSelection->new();
can_ok($w, 'add');
can_ok($w, 'remove');
can_ok($w, 'get_object');
can_ok($w, 'clear');
can_ok($w, 'count');
can_ok($w, 'replace_object');

diag 'check that different kinds of objects can be stored';
{
    $w->clear();
    my $hash = {blue => ['turquoise', 'cyan'], yellow => ['burnt sienna']};
    my $cgi_object = Statistics::WeightedSelection::TestObject->new();
    $w->add(object => $hash, weight => 1);
    $w->add(object => $hash, weight => 1, id => 'my hash');
    $w->add(object => $cgi_object, weight => 1);
    $w->add(object => $cgi_object, weight => 1, id => 'my cgi object');
    is($w->count(), 4, 'count is now 4');
    my @removed = $w->remove('my hash');
    is(scalar @removed, 1, 'got 1 object after keyed remove');
    is_deeply($removed[0], $hash, 'returned hash matches');
    is($w->count(), 3, 'count is now 3');
    @removed = $w->remove('my cgi object');
    is(scalar @removed, 1, 'got 1 object after keyed remove');
    is_deeply($removed[0], $cgi_object, 'returned hash matches');
    is($w->count(), 2, 'count is now 2');
    @removed = $w->remove($hash);
    is(scalar @removed, 1, 'got 1 object after keyed remove');
    is_deeply($removed[0], $hash, 'returned hash matches');
    is($w->count(), 1, 'count is now 1');
    @removed = $w->remove($cgi_object);
    is(scalar @removed, 1, 'got 1 object after keyed remove');
    is_deeply($removed[0], $cgi_object, 'returned hash matches');
    is($w->count(), 0, 'count is now 0');
}

diag 'consolidate single - index not at end';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 1, 'count is now 1');
    my $string = create_string();
    $w->add(object => $string, weight => 1);
    is($w->count(), 2, 'count is now 2');
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 3, 'count is now 3');
    $w->remove($string);
    is($w->count(), 2, 'count is now 2');
    check_distribution($w);
}

diag 'consolidate multiple - indexes not at end';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 1, 'count is now 1');
    my $string = create_string();
    $w->add(object => $string, weight => 1);
    is($w->count(), 2, 'count is now 2');
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 3, 'count is now 3');
    $w->add(object => $string, weight => 1);
    is($w->count(), 4, 'count is now 4');
    $w->add(object => $string, weight => 1);
    is($w->count(), 5, 'count is now 5');
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 6, 'count is now 6');
    $w->remove($string);
    is($w->count(), 3, 'count is now 3');
    check_distribution($w);
}

diag 'consolidate single - index at end';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 1, 'count is now 1');
    my $string = create_string();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 2, 'count is now 2');
    $w->add(object => $string, weight => 1);
    is($w->count(), 3, 'count is now 3');
    $w->remove($string);
    is($w->count(), 2, 'count is now 2');
    check_distribution($w);
}

diag 'consolidate multiple - 1 index at end';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 1, 'count is now 1');
    my $string = create_string();
    $w->add(object => $string, weight => 1);
    is($w->count(), 2, 'count is now 2');
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 3, 'count is now 3');
    $w->add(object => $string, weight => 1);
    is($w->count(), 4, 'count is now 4');
    $w->remove($string);
    is($w->count(), 2, 'count is now 2');
    check_distribution($w);
}

diag 'consolidate multiple - 2 indexes at end';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 1, 'count is now 1');
    my $string = create_string();
    $w->add(object => $string, weight => 1);
    is($w->count(), 2, 'count is now 2');
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 3, 'count is now 3');
    $w->add(object => $string, weight => 1);
    is($w->count(), 4, 'count is now 4');
    $w->add(object => $string, weight => 1);
    is($w->count(), 5, 'count is now 5');
    $w->remove($string);
    is($w->count(), 2, 'count is now 2');
    check_distribution($w);
}

diag 'consolidate multiple - all indexes at end';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 1, 'count is now 1');
    my $string = create_string();
    $w->add(object => $string, weight => 1);
    is($w->count(), 2, 'count is now 2');
    $w->add(object => $string, weight => 1);
    is($w->count(), 3, 'count is now 3');
    $w->add(object => $string, weight => 1);
    is($w->count(), 4, 'count is now 4');
    $w->remove($string);
    is($w->count(), 1, 'count is now 1');
    check_distribution($w);
}

diag 'insert 1 item, insert another item, get 1, then get the other, checking counts';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 1, 'count is now 1');
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 2, 'count is now 2');
    my $object = $w->get_object();
    ok($object, 'get back an object');
    is($w->count(), 1, 'count is now 1');
    $object = $w->get_object();
    ok($object, 'get back another object');
    is($w->count(), 0, 'count is now 0');
    check_distribution($w);
}

diag 'insert items, check count, clear, check count, and get no item back';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 4, 'count is now 4');
    $w->clear();
    is($w->count(), 0, 'count is now 0');
    my $object = $w->get_object();
    ok(!$object, 'did not get back an object');
    check_distribution($w);
}

diag 'insert items, check count, remove 1 item, check count';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 4, 'count is now 4');
    my $object = $w->get_object();
    ok($object, 'get back an object');
    is($w->count(), 3, 'count is now 3');
    check_distribution($w);
}

diag 'insert items, check count, remove 2 items, check count';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 4, 'count is now 4');
    my $object = $w->get_object();
    ok($object, 'get back an object');
    $object = $w->get_object();
    ok($object, 'get back another object');
    is($w->count(), 2, 'count is now 2');
    check_distribution($w);
}

diag 'insert items, check count, select 1 item with replacement, check count';
{
    my $wr = Statistics::WeightedSelection->new(with_replacement => 1);
    $wr->clear();
    $wr->add(object => create_string(), weight => 1);
    $wr->add(object => create_string(), weight => 1);
    $wr->add(object => create_string(), weight => 1);
    $wr->add(object => create_string(), weight => 1);
    is($wr->count(), 4, 'count is now 4');
    my $object = $wr->get_object();
    ok($object, 'get back an object');
    is($wr->count(), 4, 'count is now 4');
    check_distribution($wr);
}

diag 'insert items, insert item with id with same name as 1 item, remove item with id, check others still there';
{
    $w->clear();
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    $w->add(object => create_string(), weight => 1);
    is($w->count(), 4, 'count is now 4');
    my $string = create_string();
    $w->add(object => $string, weight => 1);
    $w->add(object => $string, weight => 1);
    $w->add(object => $string, weight => 1, id => 'special');
    is($w->count(), 7, 'count is now 7');
    $w->remove('special');
    is($w->count(), 6, 'count is now 6');
    check_distribution($w);
}

diag 'check distributions';
{
    $w->clear();
    $w->add(object => create_string(), weight => 12);
    $w->add(object => create_string(), weight => 5);
    $w->add(object => create_string(), weight => 9);
    $w->add(object => create_string(), weight => 2);
    $w->add(object => create_string(), weight => 3);
    $w->add(object => create_string(), weight => 1);
    check_distribution($w);
}

{
    my %distribution_check_counts;
       
    sub check_distribution {
        my ($w) = @_;
        return if !$w->count();
        return if $distribution_check_counts{join('-', map {$_->{object}} @{$w->{objects}})}++;
        my %selected_counts;
        for (1..$check_distribution_count) {
            my $w_clone = dclone $w;
            my $random = $w_clone->get_object();
            $selected_counts{$random}++;
            check_distribution($w_clone);
        }
    
        my %combined_weights;
        $combined_weights{$_->{object}} += $_->{weight} for @{$w->{objects}};
        my $total_combined_weight;
        $total_combined_weight += $_ for values %combined_weights;
    
        for my $string (keys %combined_weights) {
            ok(defined $selected_counts{$string}, "random counts of string $string detected");
            my $selected_divided_by_weight = $selected_counts{$string} / $check_distribution_count / ($combined_weights{$string} / $total_combined_weight);
            ok($selected_divided_by_weight > 0.85 && $selected_divided_by_weight < 1.15, "for $string, selected weight is $selected_divided_by_weight, which is sane");
        }
    
        return;
    }
}

sub create_string {
    return join '', map {chr(int(rand(26)) + 65)} (1..20); 
}

1;

package Statistics::WeightedSelection::TestObject;

sub new {
    return bless { t => 1, u => 2, v => 3 }, __PACKAGE__;
}

1;
