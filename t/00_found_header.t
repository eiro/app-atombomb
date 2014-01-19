use Eirotic;
use Test::More;
use App::Atombomb;

ok '#(2014-01-18T22:08:52+01:00) atom bomb first test'
    ~~ m{$App::Atombomb::FOUND_HEADER}
, "found header on single line";

is $+{title}
, 'atom bomb first test'
, "title is correct";

$_ = '

#(2014-01-18T22:08:52+01:00) atom bomb first test

';

ok m{$App::Atombomb::FOUND_HEADER}
, "found header on multi line";

is $+{title}
, 'atom bomb first test'
, "title is correct";

done_testing;


