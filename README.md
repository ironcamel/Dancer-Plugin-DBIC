# DESCRIPTION

This plugin makes it very easy to create Dancer applications that interface
with databases.
It automatically exports the keyword `schema` which returns a
DBIx::Class::Schema object.
You just need to configure your database connection information.
For performance, schema objects are cached in memory
and are lazy loaded the first time they are accessed.

# INSTALLATION

    cpan Dancer::Plugin::DBIC

# DOCUMENTATION

See [Dancer::Plugin::DBIC](https://metacpan.org/module/Dancer::Plugin::DBIC).
Also, after installation, you can view the documentation via `man` or `perldoc`:

    man Dancer::Plugin::DBIC
