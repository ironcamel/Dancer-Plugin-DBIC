# ABSTRACT: DBIx::Class interface for Dancer applications

package Dancer::Plugin::DBIC;

use strict;
use warnings;
use Dancer::Plugin;
use DBIx::Class;
use DBIx::Class::Schema::Loader;
DBIx::Class::Schema::Loader->naming('v7');

=head1 SYNOPSIS

    # Dancer Code File
    use Dancer;
    use Dancer::Plugin::DBIC;
    #use Dancer::Plugin::DBIC qw(schema); # explicit import if you like

    get '/profile/:id' => sub {
        my $user = schema->resultset('Users')->find(params->{id});
        # or explicitly ask for a schema by name:
        $user = schema('foo')->resultset('Users')->find(params->{id});
        template user_profile => { user => $user };
    };

    dance;

    # Dancer Configuration File
    plugins:
      DBIC:
        foo:
          dsn:  "dbi:SQLite:dbname=./foo.db"

Database connection details are read from your Dancer application config - see
below.

=head1 DESCRIPTION

This plugin provides an easy way to obtain L<DBIx::Class::ResultSet> instances
via the the function schema(), which it automatically imports.
You just need to point to a dsn in your L<Dancer> configuration file.
So you no longer have to write boilerplate DBIC setup code.

=head1 CONFIGURATION

Connection details will be grabbed from your L<Dancer> config file.
For example: 

    plugins:
      DBIC:
        default:
          dsn: dbi:SQLite:dbname=./foo.db
        bar:
          schema_class: Foo::Bar
          dsn:  dbi:mysql:db_foo
          user: root
          pass: secret
          options:
            RaiseError: 1
            PrintError: 1

Each schema configuration *must* have a dsn option.
The dsn option should be the L<DBI> driver connection string.
All other options are optional.

If you only have one schema configured, or one of them is called
C<default>, you can call C<schema> without an argument to get the only
or C<default> schema, respectively.

If a schema_class option is not provided, then L<DBIx::Class::Schema::Loader>
will be used to auto load the schema based on the dsn value.

The schema_class option, if provided, should be a proper Perl package name that
Dancer::Plugin::DBIC will use as a DBIx::Class::Schema class.
Optionally, a database configuation may have user, pass and options paramters
as described in the documentation for connect() in L<DBI>.

    # Note! You can also declare your connection information with the
    # following syntax:
    plugings:
      DBIC:
        foo:
          connect_info:
            - dbi:mysql:db_foo
            - root
            - secret
            -
              RaiseError: 1
              PrintError: 1

=head1 SCHEMA GENERATION

This plugin provides flexibility in defining schemas for use in your Dancer 
applications. Schemas can be generated manually by you and defined in your 
configuration file, or, they can be automatically and programmatically generated
by this plugin whenever you call the `schema` keyword, or, because this plugin
uses L<DBIx::Class::Schema::Loader> to do most of the heavy lifting, you can
use the command-line utility dbicdump to generate physical DBIC schema class
files in the current working directory. Note! The command-line utility is useful
when loading schemas large enough to discourage auto-generation and manual creation.

=cut

my $schemas = {};

register schema => sub {
    my ($dsl, $name) = plugin_args(@_);
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
        $schemas->{$name} = DBIx::Class::Schema::Loader->connect(@conn_info);
    }

    return $schemas->{$name};
};

register_plugin for_versions => [1,2];

1;
