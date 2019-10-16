package Config::Structured 1.001;

# ABSTRACT: Provides generalized and structured configuration value access

use v5.22;

use Moose;
use Moose::Util::TypeConstraints;
use Mojo::DynamicMethods -dispatch;

use Carp;
use File::Slurp qw(slurp);
use List::Util qw(reduce);
use Data::DPath qw(dpath);

use Readonly;

# Symbol constants
Readonly::Scalar our $EMPTY => q{};
Readonly::Scalar our $SLASH => q{/};

# Token value constants
Readonly::Scalar our $CONF_FROM_FILE    => q(file);
Readonly::Scalar our $CONF_FROM_ENV     => q(env);
Readonly::Scalar our $CONF_FROM_VALUES  => q(conf);
Readonly::Scalar our $CONF_FROM_DEFAULT => q(default);

#
# The configuration definition (e.g., $app.conf.def contents)
#
has 'definition' => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
);

#
# The file-based configuration (e.g., $app.conf contents)
#
has 'config_values' => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
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
# Toggle of whether to prefer the configuraiton file or ENV variables
#   Can be overridden by specific configuration nodes in the configuration definition
#
has '_priority' => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub {[$CONF_FROM_FILE, $CONF_FROM_ENV, $CONF_FROM_VALUES, $CONF_FROM_DEFAULT]},
);

#
# Convenience method for adding dynamic methods to an object
#
sub _add_helper {
  Mojo::DynamicMethods::register __PACKAGE__, @_;
}

#
# Construct path without duplicating path separators, via reduction
#
sub _concat_path {
  reduce {local $/ = $SLASH; chomp($a); join(($b =~ m|^$SLASH|) ? $EMPTY : $SLASH, $a, $b)} @_;
}

#
# Dynamically create methods at instantiation time, corresponding to configuration definition's dpaths
#
sub BUILD {
  my $self = shift;

  foreach my $el (dpath($self->_base)->match($self->definition)) {
    if (ref($el) eq 'HASH') {
      foreach my $def (keys(%{$el})) {
        $self->meta->remove_method($def);
        my $path = _concat_path($self->_base, $def);    # construct the new directive path by concatenating with our base
        if (exists($el->{$def}->{isa}))
        { # Detect whether the resulting node is a branch or leaf node (leaf nodes are required to have an "isa" attribute, though we don't (yet) perform type constraint validation)
              # leaf
          my $el = $el->{$def};
          $self->_add_helper(
            $def => sub {
              my %val;

              my $v = (@{dpath($path)->matchr($self->config_values)})[0];
              if (defined($v)) {
                if ($el->{isa} eq 'Str' && $el->{file} && ref($v) eq 'HASH' && exists($v->{FILE})) {
                  my $fn = $v->{FILE};
                  $val{$CONF_FROM_FILE} = slurp($fn) if (-f -r $fn);
                } else {
                  $val{$CONF_FROM_VALUES} = $v;
                }
              }

              $val{$CONF_FROM_ENV} = $ENV{$el->{$CONF_FROM_ENV}}
                if (defined($el->{$CONF_FROM_ENV}) && exists($ENV{$el->{$CONF_FROM_ENV}}));
              $val{$CONF_FROM_DEFAULT} = $el->{$CONF_FROM_DEFAULT} if (exists($el->{$CONF_FROM_DEFAULT}));

              my @priority = grep {defined} ($el->{priority}, @{$self->{_priority}});
              return (grep {defined} @val{@priority})[0];
            }
          );
        } else {
        # if it's a branch node, return a new Config instance with a new base location, for method chaining (e.g., config->db->pass)
          $self->_add_helper(
            $def => sub {
              return __PACKAGE__->new(
                definition    => $self->definition,
                config_values => $self->config_values,
                _base         => $path,
                _priority     => $self->_priority
              );
            }
          );
        }
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
