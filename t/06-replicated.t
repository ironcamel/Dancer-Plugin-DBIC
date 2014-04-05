use Test::More;

use lib 't/lib';
use Dancer qw(:syntax set);
use Dancer::Plugin::DBIC qw(schema rset);
use DBI;
use File::Temp qw(tempfile);
use Module::Load::Conditional qw(can_load);

my $reqs = {
    'DBD::SQLite'                  => 0,
    'Moose'                        => 0.98,
    'MooseX::Types'                => 0.21,
    'MooseX::Types::LoadableClass' => 0.011,
};

if ( can_load modules => $reqs ) {
    plan tests => 7;
} else {
    plan skip_all => "required modules to run these tests are not available";
}

my (undef, $dbfile1) = tempfile(SUFFIX => '.db');
my (undef, $dbfile2) = tempfile(SUFFIX => '.db');
my (undef, $dbfile3) = tempfile(SUFFIX => '.db');
my $dbh2 = DBI->connect("dbi:SQLite:dbname=$dbfile2");
my $dbh3 = DBI->connect("dbi:SQLite:dbname=$dbfile3");
ok $dbh2->do('create table user (name varchar(100) primary key, age int)');
ok $dbh3->do('create table user (name varchar(100) primary key, age int)');
$dbh2->do('insert into user values(?,?)', {}, 'bob', 20);
$dbh3->do('insert into user values(?,?)', {}, 'bob', 30);

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

# add a 10 year old bob to master
ok rset('User')->create({ name => 'bob', age => 10 });

# should find an older bob from one of the replicants
is rset('User')->count({ name => 'bob', age => { '>=', 20 } }), 1,
    'found older bob in one of the replicants';

# now force the query to use the master db, which has the 10 year old bob
is rset('User')->count({ name => 'bob', age => 10 }, {force_pool => 'master'}),
    1, 'found the 30 year old bob in the master db';

my %set = ();
for (1 .. 100) {
    my $bob = rset('User')->single({ name => 'bob' });
    $set{$bob->age}++;
}
is keys %set => 2, 'random balancer accessed both replicants'
    or diag explain \%set;
ok $set{20} && $set{30};

unlink $dbfile1, $dbfile2, $dbfile3;
