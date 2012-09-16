package Dancer::Plugin::DBIC;

# VERSION

use strict;
use warnings;
use Dancer::Plugin;
use DBIx::Class;

my $schemas = {};

register schema => sub {
    my $name = shift;
    my $cfg = plugin_setting;

    if (not defined $name) {
        if (keys %$cfg == 1) {
            ($name) = keys %$cfg;
        } elsif (keys %$cfg) {
            $name = "default";
        } else {
            die "No schemas are configured";
        }
    }

    return $schemas->{$name} if $schemas->{$name};

    my $options = $cfg->{$name} or die "The schema $name is not configured";

    my @conn_info = $options->{connect_info}
        ? @{$options->{connect_info}}
        : @$options{qw(dsn user pass options)};

    # pckg should be deprecated
    my $schema_class = $options->{schema_class} || $options->{pckg};

    if ($schema_class) {
        $schema_class =~ s/-/::/g;
        eval "use $schema_class";
        if ( my $err = $@ ) {
            die "error while loading $schema_class : $err";
        }
        $schemas->{$name} = $schema_class->connect(@conn_info)
    } else {
        eval { require DBIx::Class::Schema::Loader };
        if ( my $err = $@ ) {
            die "error while building schema class on the fly: DBIx::Class::Schema::Loader not available: $err"
        };
        DBIx::Class::Schema::Loader->naming('v7');
        $schemas->{$name} = DBIx::Class::Schema::Loader->connect(@conn_info);
    }

    return $schemas->{$name};
};

register_plugin;

# ABSTRACT: DBIx::Class interface for Dancer applications

=head1 SYNOPSIS

    use Dancer;
    use Dancer::Plugin::DBIC 'schema';

    get '/users/:id' => sub {
        my $user = schema->resultset('User')->find(param 'id');
        template user_profile => {
            user => $user
        };
    };

    dance;

=head1 DESCRIPTION

This plugin makes it very easy to create L<Dancer> applications that interface
with databases.
It automatically exports the keyword C<schema> which returns a
L<DBIx::Class::Schema> object.
You just need to configure your database connection information.
For performance, schema objects are cached in memory
and are lazy loaded the first time they are accessed.

=head1 CONFIGURATION

Configuration can be done in your L<Dancer> config file.
This is a minimal example. It defines one database named C<default>:

    plugins:
      DBIC:
        default:
          dsn: dbi:SQLite:dbname=some.db

In this example, there are 2 databases configured named C<default> and C<foo>:

    plugins:
      DBIC:
        default:
          dsn: dbi:SQLite:dbname=some.db
          schema_class: My::Schema
        foo:
          dsn:  dbi:mysql:foo
          schema_class: Foo::Schema
          user: bob
          pass: secret
          options:
            RaiseError: 1
            PrintError: 1

Each database configured must have a dsn option.
The dsn option should be the L<DBI> driver connection string.
All other options are optional.

If you only have one schema configured, or one of them is named
C<default>, you can call C<schema> without an argument to get the only
or C<default> schema, respectively.

If a schema_class option is not provided, then L<DBIx::Class::Schema::Loader>
will be used to dynamically load the schema based on the dsn value.
This is for convenience only and should not be used in production.
See L</"SCHEMA GENERATION"> below for caveats.

The schema_class option, should be a proper Perl package name that
Dancer::Plugin::DBIC will use as a L<DBIx::Class::Schema> class.
Optionally, a database configuation may have user, pass, and options parameters
as described in the documentation for C<connect()> in L<DBI>.

You may also declare your connection information in the following format
(which may look more familiar to DBIC users):

    plugins:
      DBIC:
        default:
          connect_info:
            - dbi:mysql:foo
            - bob
            - secret
            -
              RaiseError: 1
              PrintError: 1

=head1 USAGE

This plugin provides just the keyword C<schema> which
returns a L<DBIx::Class::Schema> object ready for you to use.
If you have configured only one database, then you can call C<schema> with
no arguments:

    my $user = schema->resultset('User')->find('bob');

If you have configured multiple databases,
you can still call C<schema> with no arguments if there is a database
named C<default> in the configuration.
Otherwise, you B<must> provide C<schema()> with the name of the database:

    my $user = schema('foo')->resultset('User')->find('bob');

=head1 SCHEMA GENERATION

There are two approaches for generating schema classes.
You may generate your own L<DBIx::Class> classes by hand and set
the corresponding C<schema_class> setting in your configuration as shown above.
This is the recommended approach for performance and stability.

It is also possible to have schema classes automatically generated via
introspection (powered by L<DBIx::Class::Schema::Loader>) if you omit the
C<schema_class> configuration setting.
However, this is highly discouraged for production environments.
The C<v7> naming scheme will be used for naming the auto generated classes.
See L<DBIx::Class::Schema::Loader::Base/naming> for more information about
naming.

For generating your own schema classes,
you can use the L<dbicdump> command line tool provided by
L<DBIx::Class::Schema::Loader> to help you.
For example, if your app were named Foo, then you could run the following
from the root of your project directory:

    dbicdump -o dump_directory=./lib Foo::Schema dbi:SQLite:/path/to/foo.db

For that example, your C<schema_class> setting would be C<Foo::Schema>.

=cut

1;
