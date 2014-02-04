use Test::More tests => 9;

use lib 't/lib';
use Dancer qw(:syntax :tests);
use Dancer::Plugin::DBIC;
use DBI;
use File::Temp qw(tempfile);
use Test::Exception;

eval { require DBD::SQLite };
plan skip_all => 'DBD::SQLite required to run these tests' if $@;

my (undef, $dbfile1) = tempfile(SUFFIX => '.db');
my (undef, $dbfile2) = tempfile(SUFFIX => '.db');

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

my $dbh1 = DBI->connect("dbi:SQLite:dbname=$dbfile1");
my $dbh2 = DBI->connect("dbi:SQLite:dbname=$dbfile2");

ok $dbh1->do(q{ create table user (name varchar(100) primary key, age int) }),
    "created sqlite test db $dbfile1";
$dbh1->do('insert into user values(?,?)', {}, 'bob', 30);

ok $dbh2->do(q{ create table user (name varchar(100) primary key, age int) }),
    "created sqlite test db $dbfile2";
$dbh2->do(q{ insert into user values(?,?) }, {}, 'sue', 20);

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

subtest 'default schema' => sub {
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
