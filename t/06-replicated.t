use Test::More tests => 5;

use lib 't/lib';
use Dancer qw(:syntax set);
use Dancer::Plugin::DBIC qw(schema rset);
use DBI;
use File::Temp qw(tempfile);

eval { require DBD::SQLite };
plan skip_all => 'DBD::SQLite required to run these tests' if $@;

my (undef, $dbfile1) = tempfile(SUFFIX => '.db');
my (undef, $dbfile2) = tempfile(SUFFIX => '.db');
my (undef, $dbfile3) = tempfile(SUFFIX => '.db');
my $dbh2 = DBI->connect("dbi:SQLite:dbname=$dbfile2");
my $dbh3 = DBI->connect("dbi:SQLite:dbname=$dbfile3");
ok $dbh2->do('create table user (name varchar(100) primary key, age int)');
ok $dbh3->do('create table user (name varchar(100) primary key, age int)');
$dbh2->do('insert into user values(?,?)', {}, 'bob', 40);
$dbh3->do('insert into user values(?,?)', {}, 'bob', 40);

set plugins => {
    DBIC => {
        default => {
            dsn          => "dbi:SQLite:dbname=$dbfile1",
            schema_class => 'Foo',
            replicated => {
                balancer_type => '::Random',
                replicants => [
                    [ "dbi:SQLite:dbname=$dbfile2" ],
                    [ "dbi:SQLite:dbname=$dbfile3" ],
                ],
            },
        },
    },
};

schema->deploy;

# add a 30 year old bob to master
ok rset('User')->create({ name => 'bob', age => 30 });

# should find the 40 year old bob from one of the slaves
is rset('User')->count({ name => 'bob', age => 40 }), 1, 'found bob';

# now force the query to use the master db, which has the 30 year old bob
is rset('User')->count({ name => 'bob', age => 30 }, {force_pool => 'master'}),
    1, 'found the 30 year old bob in the master db';

unlink $dbfile1, $dbfile2, $dbfile3;
