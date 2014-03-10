use Test::More tests => 2;

use lib 't/lib';
use Dancer qw(:syntax set);
use Dancer::Plugin::DBIC qw(schema);
use File::Temp qw(tempfile);
use Test::Exception;

eval { require DBD::SQLite };
plan skip_all => 'DBD::SQLite required to run these tests' if $@;

my (undef, $dbfile1) = tempfile(SUFFIX => '.db');
my (undef, $dbfile2) = tempfile(SUFFIX => '.db');

subtest 'two schemas' => sub {
    set plugins => {
        DBIC => {
            foo => {
                schema_class => 'Foo',
                dsn =>  "dbi:SQLite:dbname=$dbfile1",
            },
            bar => {
                schema_class => 'Foo',
                dsn =>  "dbi:SQLite:dbname=$dbfile2",
            },
        }
    };

    schema('foo')->deploy;
    ok schema('foo')->resultset('User')->create({ name => 'bob', age => 30 });
    schema('bar')->deploy;
    ok schema('bar')->resultset('User')->create({ name => 'sue', age => 20 });

    my $user = schema('foo')->resultset('User')->find('bob');
    ok $user, 'found bob';
    is $user->age => '30', 'bob is getting old';

    $user = schema('bar')->resultset('User')->find('sue');
    ok $user, 'found sue';
    is $user->age => '20', 'sue is the right age';

    throws_ok { schema('poo')->resultset('User')->find('bob') }
        qr/schema poo is not configured/, 'Missing schema error thrown';

    throws_ok { schema->resultset('User')->find('bob') }
        qr/The schema default is not configured/,
        'Missing default schema error thrown';
};

subtest 'two schemas with a default schema' => sub {
    set plugins => {
        DBIC => {
            default => {
                schema_class => 'Foo',
                dsn =>  "dbi:SQLite:dbname=$dbfile1",
            },
            bar => {
                schema_class => 'Foo',
                dsn =>  "dbi:SQLite:dbname=$dbfile2",
            },
        }
    };

    ok my $bob = schema->resultset('User')->find('bob'), 'found bob';
    is $bob->age => 30;
};

unlink $dbfile1, $dbfile2;
