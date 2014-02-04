# Test a schema with read-slaves configured. The schema will be auto-deployed
# due to sheer laziness. These tests require DBIx::Class::Schema::Loader to be
# installed.

use strict;
use warnings;
use Test::More;

use Dancer qw(:syntax !pass);
use Dancer::Plugin::DBIC;
use DBI;
use File::Temp;

eval { require DBD::SQLite; require DBIx::Class::Schema::Loader };
if ($@) {
    plan skip_all =>
        'DBD::SQLite and DBIx::Class::Schema::Loader required for these tests';
} else {
    plan tests => 7;
}

my @dbfiles = map { File::Temp->new(SUFFIX => '.db')->filename } 0..3;

set plugins => {
    DBIC => {
        foo => {
            dsn =>  "dbi:SQLite:dbname=$dbfiles[0]",
            read_slaves => [
                {dsn =>  "dbi:SQLite:dbname=$dbfiles[1]"},
                {dsn =>  "dbi:SQLite:dbname=$dbfiles[2]"},
                {dsn =>  "dbi:SQLite:dbname=$dbfiles[3]"},
            ]
        }
    }
};

DBI->connect("dbi:SQLite:dbname=$_")
    ->do('create table user (name varchar(100) primary key, time int)')
        for @dbfiles;

my $users = schema('foo')->resultset('User');
ok $users->new({name => 'Happy', time => time})->insert, 'Happy inserted';
ok $users->new({name => 'Dopey', time => time})->insert, 'Dopey inserted';
ok $users->new({name => 'Sleepy', time => time})->insert, 'Sleepy inserted';
ok $users->new({name => 'Grumpy', time => time})->insert, 'Grumpy inserted';
ok $users->new({name => 'Sneezy', time => time})->insert, 'Sneezy inserted';
ok !$users->count, 'Read slaves do not have any data';
ok $users->search(undef, {force_pool=>'master'})->count, 'Master has data';

unlink for @dbfiles;
