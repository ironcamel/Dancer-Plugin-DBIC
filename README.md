# NAME

Dancer::Plugin::DBIC - DBIx::Class interface for Dancer applications

# VERSION

version 0.2000

# SYNOPSIS

    use Dancer;
    use Dancer::Plugin::DBIC qw(schema resultset rset);

    get '/users/:user_id' => sub {
        my $user = schema('default')->resultset('User')->find(param 'user_id');

        # If you are accessing the 'default' schema, then all the following
        # are equivalent to the above:
        $user = schema->resultset('User')->find(param 'user_id');
        $user = resultset('User')->find(param 'user_id');
        $user = rset('User')->find(param 'user_id');

        template user_profile => {
            user => $user
        };
    };

    dance;

# DESCRIPTION

This plugin makes it very easy to create [Dancer](http://search.cpan.org/perldoc?Dancer) applications that interface
with databases.
It automatically exports the keyword `schema` which returns a
[DBIx::Class::Schema](http://search.cpan.org/perldoc?DBIx::Class::Schema) object.
You just need to configure your database connection information.
For performance, schema objects are cached in memory
and are lazy loaded the first time they are accessed.

# CONFIGURATION

Configuration can be done in your [Dancer](http://search.cpan.org/perldoc?Dancer) config file.
This is a minimal example. It defines one database named `default`:

    plugins:
      DBIC:
        default:
          dsn: dbi:SQLite:dbname=some.db

In this example, there are 2 databases configured named `default` and `foo`:

    plugins:
      DBIC:
        default:
          dsn: dbi:SQLite:dbname=myapp.db
          schema_class: MyApp::Schema
        foo:
          dsn: dbi:Pg:dbname=foo
          schema_class: Foo::Schema
          user: bob
          password: secret
          options:
            RaiseError: 1
            PrintError: 1

Each database configured must at least have a dsn option.
The dsn option should be the [DBI](http://search.cpan.org/perldoc?DBI) driver connection string.
All other options are optional.

If you only have one schema configured, or one of them is named
`default`, you can call `schema` without an argument to get the only
or `default` schema, respectively.

If a schema\_class option is not provided, then [DBIx::Class::Schema::Loader](http://search.cpan.org/perldoc?DBIx::Class::Schema::Loader)
will be used to dynamically load the schema by introspecting the database
corresponding to the dsn value.
Remember that you need [DBIx::Class::Schema::Loader](http://search.cpan.org/perldoc?DBIx::Class::Schema::Loader) installed to take
advantage of that.

The schema\_class option, should be a proper Perl package name that
Dancer::Plugin::DBIC will use as a [DBIx::Class::Schema](http://search.cpan.org/perldoc?DBIx::Class::Schema) class.
Optionally, a database configuation may have user, password, and options
parameters as described in the documentation for `connect()` in [DBI](http://search.cpan.org/perldoc?DBI).

Alternatively, you may also declare your connection information inside an
array named `connect_info`:

    plugins:
      DBIC:
        default:
          connect_info:
            - dbi:Pg:dbname=foo
            - bob
            - secret
            -
              RaiseError: 1
              PrintError: 1

You can also add database read slaves to your configuration with the
`replicated` config option.
This will automatically make your read queries go to a slave and your write
queries go to the master.
Keep in mind that this will require additional dependencies:
[DBIx::Class::Optional::Dependencies\#Storage::Replicated](http://search.cpan.org/perldoc?DBIx::Class::Optional::Dependencies\#Storage::Replicated)
See [DBIx::Class::Storage::DBI::Replicated](http://search.cpan.org/perldoc?DBIx::Class::Storage::DBI::Replicated) for more details.
Here is an example configuration that adds two read slaves:

    plugins:
      DBIC:
        default:
          schema_class: Foo
          dsn: dbi:Pg:dbname=master
          replicated:
            balancer_type: ::Random  # defaults to '::Random' if not provided
            replicants:
              -
                - dbi:Pg:dbname=slave1
                - user1
                - password1
              -
                - dbi:Pg:dbname=slave2
                - user2
                - password2

Schema aliases allow you to reference the same underlying database by multiple
names.
For example:

    plugins:
      DBIC:
        default:
          dsn: dbi:Pg:dbname=master
          schema_class: MyApp::Schema
        slave1:
          alias: default

Now you can access the default schema with `schema()`, `schema('default')`,
or `schema('slave1')`.
This can come in handy if, for example, you have master/slave replication in
your production environment but only a single database in your development
environment.
You can continue to reference `schema('slave1')` in your code in both
environments by simply creating a schema alias in your development.yml config
file, as shown above.

# FUNCTIONS

## schema

    my $user = schema->resultset('User')->find('bob');

The `schema` keyword returns a [DBIx::Class::Schema](http://search.cpan.org/perldoc?DBIx::Class::Schema) object ready for you to
use.
If you have configured only one database, then you can simply call `schema`
with no arguments.
If you have configured multiple databases,
you can still call `schema` with no arguments if there is a database
named `default` in the configuration.
With no argument, the `default` schema is returned.
Otherwise, you __must__ provide `schema()` with the name of the database:

    my $user = schema('foo')->resultset('User')->find('bob');

## resultset

This is a convenience method that will save you some typing.
Use this __only__ when accessing the `default` schema.

    my $user = resultset('User')->find('bob');

is equivalent to:

    my $user = schema->resultset('User')->find('bob');

## rset

    my $user = rset('User')->find('bob');

This is simply an alias for `resultset`.

# SCHEMA GENERATION

There are two approaches for generating schema classes.
You may generate your own [DBIx::Class](http://search.cpan.org/perldoc?DBIx::Class) classes and set
the corresponding `schema_class` setting in your configuration as shown above.
This is the recommended approach for performance and stability.

It is also possible to have schema classes dynamically generated
if you omit the `schema_class` configuration setting.
This requires you to have [DBIx::Class::Schema::Loader](http://search.cpan.org/perldoc?DBIx::Class::Schema::Loader) installed.
The `v7` naming scheme will be used for naming the auto generated classes.
See ["naming" in DBIx::Class::Schema::Loader::Base](http://search.cpan.org/perldoc?DBIx::Class::Schema::Loader::Base#naming) for more information about
naming.

For generating your own schema classes,
you can use the [dbicdump](http://search.cpan.org/perldoc?dbicdump) command line tool provided by
[DBIx::Class::Schema::Loader](http://search.cpan.org/perldoc?DBIx::Class::Schema::Loader) to help you.
For example, if your app were named Foo, then you could run the following
from the root of your project directory:

    dbicdump -o dump_directory=./lib Foo::Schema dbi:SQLite:/path/to/foo.db

For that example, your `schema_class` setting would be `Foo::Schema`.

# CONTRIBUTORS

- Alexis Sukrieh <sukria@sukria.net>
- Dagfinn Ilmari Mannsåker <[https://github.com/ilmari](https://github.com/ilmari)\>
- David Precious <davidp@preshweb.co.uk>
- Fabrice Gabolde <[https://github.com/fgabolde](https://github.com/fgabolde)\>
- Franck Cuny <franck@lumberjaph.net>
- Steven Humphrey <[https://github.com/shumphrey](https://github.com/shumphrey)\>
- Yanick Champoux <[https://github.com/yanick](https://github.com/yanick)\>

# AUTHORS

- Al Newkirk <awncorp@cpan.org>
- Naveed Massjouni <naveed@vt.edu>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
