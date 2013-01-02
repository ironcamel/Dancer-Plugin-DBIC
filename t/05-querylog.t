use strict;
use warnings;

use Test::More;

BEGIN {
    unless (eval {
        require DBD::SQLite;
        require Plack::Test;
        require Plack::Middleware::DBIC::QueryLog;
        1;
    }) {
        plan skip_all => "DBD::SQLite, Plack::Test and Plack::Middleware::DBIC::QueryLog required to run these tests";
    }
}

{
    package QueryLogApp;
    use Dancer;
    use lib 't/lib';

    use DBI;
    use File::Temp qw(tempfile);

    use Dancer::Plugin::DBIC;
    use Plack::Middleware::DBIC::QueryLog;

    my (undef, $dbfile) = tempfile(SUFFIX => '.db');

    set plugins => {
        DBIC => {
            foo => {
                schema_class => 'Foo',
                dsn =>  "dbi:SQLite:dbname=$dbfile",
            },
        },
    };

    set apphandler => 'PSGI';

    set plack_middlewares => [
        ['DBIC::QueryLog'],
    ];

    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile");
    $dbh->do(q{
         create table user (name varchar(100) primary key, age int)
    });

    get '/' => sub {
        schema->resultset('User')->count;
        my $ql = Plack::Middleware::DBIC::QueryLog->get_querylog_from_env(request->env);
        $ql->count;
    };
}

use HTTP::Request::Common;
use Plack::Test;

test_psgi
    app => QueryLogApp->dance,
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        ok $res->is_success, "querylog request successful";
        is $res->content, "1", "one query executed";
    };

done_testing;
