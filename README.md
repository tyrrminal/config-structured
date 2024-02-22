# NAME

Config::Structured  - provides generalized and structured configuration value access

# SYNOPSIS

Basic usage:

    use Config::Structured;

    my $conf = Config::Structured->new(
      structure => { 
        db => {
          host     => {
            isa         => 'Str',
            default     => 'localhost',
            description => 'the database server hostname',
          },
          username => {
            isa         => 'Str',
            default     => 'dbuser',
            description => 'the database user's username',
          },
          password => {
            isa         => 'Str',
            description => 'the database user's password',
          },
        }
      },
      config => { 
        db => {
          username => 'appuser',
          host     => {
            source   => 'env',
            ref      => 'DB_HOSTNAME',
          },
          password => {
            source => 'file',
            ref    => '/run/secrets/db_password',
          },
        }
      }
    );

    say $conf->db->username(); # appuser
    # assuming that the hostname value has been set in the DB_HOSTNAME env var
    say $conf->db->host; # prod_db_1.mydomain.com
    # assuming that the password value has been stored in /run/secrets/db_password
    say $conf->db->password(); # *mD9ua&ZSVzEeWkm93bmQzG

Hooks example showing how to ensure config directories exist prior to first 
use:

    my $conf = Config::Structured->new(
      ...
      hooks => {
        '/paths/*' => {
          on_load => sub($node,$value) {
            Mojo::File->new($value)->make_path
          }
        }
      }
    )

# DESCRIPTION

[Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) provides a structured method of accessing configuration values

This is predicated on the use of a configuration `structure` (required), This structure
provides a hierarchical structure of configuration branches and leaves. Each branch becomes
a [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) method which returns a new [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) instance rooted at
that node, while each leaf becomes a method which returns the configuration value.

The configuration value is normally provided in the `config` hash. However, a `config` node
for a non-Hash value can be a hash containing the "source" and "ref" keys. This permits sourcing
the config value from a file (when source="file") whose filesystem location is given in the "ref"
value, or an environment variable (when source="env") whose name is given in the "ref" value.

_Structure Leaf Nodes_ are required to include an "isa" key, whose value is a type 
(see [Moose::Util::TypeConstraints](https://metacpan.org/pod/Moose%3A%3AUtil%3A%3ATypeConstraints)). If typechecking is not required, use isa => 'Any'.
There are a few other keys that [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) respects in a leaf node:

- `default`

    This key's value is the default configuration value if a data source or value is not provided by
    the configuation.

- `description`
- `notes`

    A human-readable description and implementation notes, respectively, of the configuration node. 
    [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) does not do anything with these values at present, but they provides inline 
    documentation of configuration directivess within the structure (particularly useful in the common 
    case where the structure is read from a file)

Besides `structure` and `config`, [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) also accepts a `hooks` argument at 
initialization time. This argument must be a HashRef whose keys are patterns matching config
node paths, and whose values are HashRefs containing `on_load` and/or `on_access` keys. These
in turn point to CodeRefs which are run when the config value is initially loaded, or every time
it is accessed, respectively.

# CONSTRUCTORS

## Config::Structured->new( config => {...}, structure => {...} )

Returns a new `Config::Structured` instance. `config` and `structure` are
required parameters and must either be HashRefs or strings containing a data
structure in `JSON`, `YAML`, or `perl` (i.e., [Data::Dumper](https://metacpan.org/pod/Data%3A%3ADumper)) formats. The
format of the structure will be autodetected. The content of these data 
structures is detailed above in the `DESCRIPTION` section.

# METHODS

## get( \[$name\] )

Class method.

Returns a registered [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) instance.  If `$name` is not provided, returns the default instance.
Instances can be registered with `__register_default` or `__register_as`. This mechanism is used to provide
global access to a configuration, even from code contexts that otherwise cannot share data.

## \_\_register\_default()

Call on a [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) instance to set the instance as the default.

## \_\_register\_as( $name )

Call on a [Config::Structured](https://metacpan.org/pod/Config%3A%3AStructured) instance to register the instance as the provided name.

## \_\_get\_child\_node\_names()

Returns a list of names (strings) of all immediate child nodes of the current config node

# AUTHOR

Mark Tyrrell `<mark@tyrrminal.dev>`

# LICENSE

Copyright (c) 2024 Mark Tyrrell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
