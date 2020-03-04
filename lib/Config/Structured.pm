package Config::Structured;

# ABSTRACT: Provides generalized and structured configuration value access

=head1 SYNOPSIS

  use Config::Structured;

  my $conf = Config::Structured->new(
    structure    => { ... },
    config       => { ... }
  );

  say $conf->some->nested->value();

=head1 DESCRIPTION

  L<Config::Structured> provides a structured method of accessing configuration values

  This is predicated on the use of a configuration C<structure> (required), This structure
  provides a hierarchical structure of configuration branches and leaves. Each branch becomes
  a L<Config::Structured> method which returns a new L<Config::Structured> instance rooted at
  that node, while each leaf becomes a method which returns the configuration value.

  The configuration value is normally provided in the C<config> hash, which mirrors the
  tree structue of the structure, but the leaf structure can also specify that it is permitted 
  to come from an environment variable value. The value may also come from the contents of a file
  by specifying a reference to a string containing the filename/path in the C<config>

  I<Structure Leaf Nodes> are required to include an "isa" key, whose value is a type 
  (see L<Moose::Util::TypeConstraints>). Types are not currently checked (except in one 
  special case) but the existence of this key is what identifies the node as a leaf. There are
  a few other keys that L<Config::Structured> respects in a leaf node:

  =over

  =item C<env>

  This key's value is the name of an environment variable whose value should be returned for this node.

  If the variable in question is not set, C<env> is ignored.

  =item C<default>

  This key's value is the default configuration value if L<Config::Structured> cannot ascertain a 
  more-applicable value from other sources

  =item C<description>

  =item C<notes>

  A human-readable description and implementation nodes, respectively, of the configuration node. 
  L<Config::Structured> does not do anything with these values at present, but they provides inline 
  documentation of configuration directivess within the structure (particularly useful in the common 
  case where the structure is read from a file)

  =back

=method get($name?)

Class method.

Returns a registered L<Config::Structured> instance.  If C<$name> is not provided, returns the default instance.
Instances can be registered with C<__register_default> or C<__register_as>. This mechanism is used to provide
global access to a configuration, even from code contexts that otherwise cannot share data.

=method __register_default()

Call on a L<Config::Structured> instance to set the instance as the default.

=method __register_as($name)

Call on a L<Config::Structured> instance to register the instance as the provided name.

=cut
use 5.022;

use Moose;
use Moose::Util::TypeConstraints;
use Mojo::DynamicMethods -dispatch;

use Syntax::Keyword::Junction;
use Carp;
use File::Slurp qw(slurp);
use List::Util qw(reduce);
use Data::DPath qw(dpath);

use Readonly;

use Config::Structured::Deserializer;

# Symbol constants
Readonly::Scalar my $EMPTY => q{};
Readonly::Scalar my $SLASH => q{/};

# Token key constants
Readonly::Scalar my $DEF_ISA     => q{isa};
Readonly::Scalar my $DEF_DEFAULT => q{default};
Readonly::Scalar my $CFG_SOURCE  => q{source};
Readonly::Scalar my $CFG_REF     => q{ref};

# Token value constants
Readonly::Scalar my $CONF_FROM_FILE => q(file);
Readonly::Scalar my $CONF_FROM_ENV  => q(env);

# Method names that are needed by Config::Structured and cannot be overridden by config node names
Readonly::Array my @RESERVED =>
  qw(get meta BUILD BUILD_DYNAMIC _config _structure _base _add_helper __register_default __register_as);

#
# The configuration structure (e.g., $app.conf.def contents)
#
has '_structure_v' => (
  is       => 'ro',
  isa      => 'Str|HashRef',
  init_arg => 'structure',
  required => 1,
);

has '_structure' => (
  is       => 'ro',
  isa      => 'HashRef',
  init_arg => undef,
  lazy     => 1,
  default  => sub {Config::Structured::Deserializer->decode(shift->_structure_v)}
);

#
# The file-based configuration (e.g., $app.conf contents)
#
has '_config_v' => (
  is       => 'ro',
  isa      => 'Str|HashRef',
  init_arg => 'config',
  required => 1,
);

has '_config' => (
  is       => 'ro',
  isa      => 'HashRef',
  init_arg => undef,
  lazy     => 1,
  default  => sub {Config::Structured::Deserializer->decode(shift->_config_v)}
);

#
# This instance's base path (e.g., /db)
#   Recursively constucted through re-instantiation of non-leaf config nodes
#
has '_base' => (
  is      => 'ro',
  isa     => 'Str',
  default => $SLASH,
);

#
# Convenience method for adding dynamic methods to an object
#
sub _add_helper {
  Mojo::DynamicMethods::register __PACKAGE__, @_;
}

#
# Dynamically create methods at instantiation time, corresponding to configuration structure's dpaths
# Use lexical subs and closures to avoid polluting namespace unnecessarily (preserving it for config nodes)
#
sub BUILD {
  my $self = shift;

  # lexical subroutines

  state sub carpp {
    carp('[' . __PACKAGE__ . '] ' . shift());
  }

  state sub is_hashref {
    my $node = shift;
    return ref($node) eq 'HASH';
  }

  state sub is_leaf_node {
    my $node = shift;
    exists($node->{isa});
  }

  state sub is_value_from_file_contents {
    my $node = shift;
    return ref($node) eq 'SCALAR';
  }

  state sub file_content_value {
    my $node = shift;
    my $fn   = ${$node};
    if (-f -r $fn) {
      chomp(my $contents = slurp($fn));
      return $contents;
    }
    return;
  }

  state sub concat_path {
    reduce {local $/ = $SLASH; chomp($a); join(($b =~ m|^$SLASH|) ? $EMPTY : $SLASH, $a, $b)} @_;
  }

  # Closures

  my $get_child_nodes = sub {
    my $base = shift;
    return dpath($base)->match($self->_structure);
  };

  my $conf_value_for_path = sub {
    my $path   = shift;
    my $v_conf = dpath($path)->matchr($self->_config);
    if (scalar(@{$v_conf})) {
      my $v = $v_conf->[0];
      #scalar references point to filenames from which to pull the config value
      return $CONF_FROM_FILE   => file_content_value($v) if (is_value_from_file_contents($v));
      return $CONF_FROM_VALUES => $v;
    }
  };

  my $make_leaf_generator = sub {
    my ($el, $path) = @_;
    return sub {
      my %val = $conf_value_for_path->($path);

      $val{$CONF_FROM_ENV} = $ENV{$el->{$CONF_FROM_ENV}}
        if (defined($el->{$CONF_FROM_ENV}) && exists($ENV{$el->{$CONF_FROM_ENV}}));
      $val{$CONF_FROM_DEFAULT} = $el->{$CONF_FROM_DEFAULT} if (exists($el->{$CONF_FROM_DEFAULT}));

      my @priority = grep {exists($val{$_})} grep {defined} ($el->{priority}, @{$self->{_priority}});
      return (@val{@priority})[0];
    }
  };

  my $make_branch_generator = sub {
    my $path = shift;
    return sub {
      return __PACKAGE__->new(
        structure => $self->_structure,
        config    => $self->_config,
        _base     => $path,
        _priority => $self->_priority
      );
    }
  };

  foreach my $el ($get_child_nodes->($self->_base)) {
    if (is_hashref($el)) {
      foreach my $def (keys(%{$el})) {
        carpp("Reserved word '$def' used as config node name: ignored") and next if ($def eq any(@RESERVED));
        $self->meta->remove_method($def)
          ;    # if the config node refers to a method already defined on our instance, remove that method
        my $path = concat_path($self->_base, $def);    # construct the new directive path by concatenating with our base

# Detect whether the resulting node is a branch or leaf node (leaf nodes are required to have an "isa" attribute, though we don't (yet) perform type constraint validation)
# if it's a branch node, return a new Config instance with a new base location, for method chaining (e.g., config->db->pass)
        $self->_add_helper(
          $def => (is_leaf_node($el->{$def}) ? $make_leaf_generator->($el->{$def}, $path) : $make_branch_generator->($path)));
      }
    }
  }
}

#
# Handle dynamic method dispatch
#
sub BUILD_DYNAMIC {
  my ($class, $method, $dyn_methods) = @_;
  return sub {
    my ($self, @args) = @_;
    my $dynamic = $dyn_methods->{$self}{$method};
    return $self->$dynamic(@args) if ($dynamic);
    my $package = ref $self;
    croak qq{Can't locate object method "$method" via package "$package"};
  }
}

#
# Saved Named/Default Config instances
#
our $saved_instances = {
  default => undef,
  named   => {}
};

#
# Instance method
# Saves the current instance as the default instance
#
sub __register_default {
  my $self = shift;
  $saved_instances->{default} = $self;
  return $self;
}

#
# Instance method
# Saves the current instance by the specified name
# Parameters:
#  Name (Str), required
#
sub __register_as {
  my $self = shift;
  my ($name) = @_;

  croak 'Registration name is required' unless (defined $name);

  $saved_instances->{named}->{$name} = $self;
  return $self;
}

#
# Class method
# Return a previously saved instance. Returns undef if no instances have been saved. Returns the default instance if no name is provided
# Parameters:
#  Name (Str), optional
#
sub get {
  my $class = shift;
  my ($name) = @_;

  if (defined $name) {
    return $saved_instances->{named}->{$name};
  } else {
    return $saved_instances->{default};
  }
}

1;
