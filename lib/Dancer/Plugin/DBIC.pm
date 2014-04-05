package Dancer::Plugin::DBIC;

# VERSION

use strict;
use warnings;
use utf8;
use Dancer::Plugin;
use Module::Load;

my $schemas = {};

sub schema {
    my ($self, $name) = plugin_args(@_);
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
    if ( my $alias = $options->{alias} ) {
        $options = $cfg->{$alias}
            or die "The schema alias $alias does not exist in the config";
        return $schemas->{$alias} if $schemas->{$alias};
    }

    my @conn_info = $options->{connect_info}
        ? @{$options->{connect_info}}
        : @$options{qw(dsn user password options)};
    if ( exists $options->{pass} ) {
        warn "The pass option is deprecated. Use password instead.";
        $conn_info[2] = $options->{pass};
    }

    my $schema;

    if ( my $schema_class = $options->{schema_class} ) {
        $schema_class =~ s/-/::/g;
        eval { load $schema_class };
        die "Could not load schema_class $schema_class: $@" if $@;
        if ( my $replicated = $options->{replicated} ) {
            $schema = $schema_class->clone;
            my %storage_options;
            my @params = qw( balancer_type balancer_args pool_type pool_args );
            for my $p ( @params ) {
                my $value = $replicated->{$p};
                $storage_options{$p} = $value if defined $value;
            }
            $schema->storage_type([ '::DBI::Replicated', \%storage_options ]);
            $schema->connection( @conn_info );
            $schema->storage->connect_replicants( @{$replicated->{replicants}});
        } else {
            $schema = $schema_class->connect( @conn_info );
        }
    } else {
        my $dbic_loader = 'DBIx::Class::Schema::Loader';
        eval { load $dbic_loader };
        die "You must provide a schema_class option or install $dbic_loader."
            if $@;
        $dbic_loader->naming( $options->{schema_loader_naming} || 'v7' );
        $schema = DBIx::Class::Schema::Loader->connect(@conn_info);
    }

    return $schemas->{$name} = $schema;
};

sub resultset {
    my ($self, $rset_name) = plugin_args(@_);
    return schema->resultset($rset_name);
}

register schema    => \&schema;
register resultset => \&resultset;
register rset      => \&resultset;
register_plugin for_versions => [ 1, 2 ];

# ABSTRACT: DBIx::Class interface for Dancer applications

=encoding utf8

=head1 SYNOPSIS

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

=head2 simple example

Here is a simple example. It defines one database named C<default>:

    plugins:
      DBIC:
        default:
          dsn: dbi:SQLite:dbname=myapp.db
          schema_class: MyApp::Schema

=head2 multiple schemas

In this example, there are 2 databases configured named C<default> and C<foo>:

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
The dsn option should be the L<DBI> driver connection string.
All other options are optional.

If you only have one schema configured, or one of them is named
C<default>, you can call C<schema> without an argument to get the only
or C<default> schema, respectively.

If a schema_class option is not provided, then L<DBIx::Class::Schema::Loader>
will be used to dynamically load the schema by introspecting the database
corresponding to the dsn value.
You need L<DBIx::Class::Schema::Loader> installed for this to work.

WARNING: Dynamic loading is not recommended for production environments.
It is almost always better to provide a schema_class option.

The schema_class option should be the name of your L<DBIx::Class::Schema> class.
See L</"SCHEMA GENERATION">
Optionally, a database configuration may have user, password, and options
parameters as described in the documentation for C<connect()> in L<DBI>.

=head2 connect_info

Alternatively, you may also declare your connection information inside an
array named C<connect_info>:

    plugins:
      DBIC:
        default:
          schema_class: MyApp::Schema
          connect_info:
            - dbi:Pg:dbname=foo
            - bob
            - secret
            -
              RaiseError: 1
              PrintError: 1

=head2 replicated

You can also add database read slaves to your configuration with the
C<replicated> config option.
This will automatically make your read queries go to a slave and your write
queries go to the master.
Keep in mind that this will require additional dependencies:
L<DBIx::Class::Optional::Dependencies#Storage::Replicated>
See L<DBIx::Class::Storage::DBI::Replicated> for more details.
Here is an example configuration that adds two read slaves:

    plugins:
      DBIC:
        default:
          schema_class: MyApp::Schema
          dsn: dbi:Pg:dbname=master
          replicated:
            balancer_type: ::Random     # optional
            balancer_args:              # optional
                auto_validate_every: 5  # optional
                master_read_weight:1    # optional
            # pool_type and pool_args are also allowed and are also optional
            replicants:
              -
                - dbi:Pg:dbname=slave1
                - user1
                - password1
                -
                  quote_names: 1
                  pg_enable_utf8: 1
              -
                - dbi:Pg:dbname=slave2
                - user2
                - password2
                -
                  quote_names: 1
                  pg_enable_utf8: 1

=head2 alias

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

Now you can access the default schema with C<schema()>, C<schema('default')>,
or C<schema('slave1')>.
This can come in handy if, for example, you have master/slave replication in
your production environment but only a single database in your development
environment.
You can continue to reference C<schema('slave1')> in your code in both
environments by simply creating a schema alias in your development.yml config
file, as shown above.

=head1 FUNCTIONS

=head2 schema

    my $user = schema->resultset('User')->find('bob');

The C<schema> keyword returns a L<DBIx::Class::Schema> object ready for you to
use.
If you have configured only one database, then you can simply call C<schema>
with no arguments.
If you have configured multiple databases,
you can still call C<schema> with no arguments if there is a database
named C<default> in the configuration.
With no argument, the C<default> schema is returned.
Otherwise, you B<must> provide C<schema()> with the name of the database:

    my $user = schema('foo')->resultset('User')->find('bob');

=head2 resultset

This is a convenience method that will save you some typing.
Use this B<only> when accessing the C<default> schema.

    my $user = resultset('User')->find('bob');

is equivalent to:

    my $user = schema->resultset('User')->find('bob');

=head2 rset

    my $user = rset('User')->find('bob');

This is simply an alias for C<resultset>.

=head1 SCHEMA GENERATION

Setting the schema_class option and having proper DBIx::Class classes
is the recommended approach for performance and stability.
You can use the L<dbicdump> command line tool provided by
L<DBIx::Class::Schema::Loader> to help you.
For example, if your app were named Foo, then you could run the following
from the root of your project directory:

    dbicdump -o dump_directory=./lib Foo::Schema dbi:SQLite:/path/to/foo.db

For this example, your C<schema_class> setting would be C<'Foo::Schema'>.

=head1 CONTRIBUTORS

=over 4

=item *

Alexis Sukrieh <sukria@sukria.net>

=item *

Dagfinn Ilmari Mannsåker <L<https://github.com/ilmari>>

=item *

David Precious <davidp@preshweb.co.uk>

=item *

Fabrice Gabolde <L<https://github.com/fgabolde>>

=item *

Franck Cuny <franck@lumberjaph.net>

=item *

Steven Humphrey <L<https://github.com/shumphrey>>

=item *

Yanick Champoux <L<https://github.com/yanick>>

=back

=cut

1;
