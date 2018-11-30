package Concert::Config 0.003;

# ABSTRACT: Provides generalized and structured configuration value access from Mojolicious

use Moose;
use Moose::Util::TypeConstraints;
use Mojo::DynamicMethods -dispatch;

use Carp;
use List::Util qw(reduce);
use Data::DPath qw(dpath);

use Concert::Constants;
Readonly::Scalar our $CONF_FROM_ENV   => q(env);
Readonly::Scalar our $CONF_FROM_FILE  => q(conf);

#
# This instance's base path (e.g., /db)
#   Recursively constucted through re-instantiation of non-leaf config nodes
#
has '_base' => (
  is      => 'ro',
  isa     => 'Str',
  default => '/'
);

#
# The configuration definition, from the .conf.def file
#
has '_def' => (
  is       => 'ro',
  isa      => 'HashRef',
  required => $TRUE
);

#
# The file-based configuration (e.g., $moniker.conf contents)
#
has '_conf' => (
  is       => 'ro',
  isa      => 'HashRef',
  required => $TRUE
);

#
# Toggle of whether to prefer the configuraiton file or ENV variables
#   Can be overridden by specific configuration nodes in the configuration definition
# 
has '_priority' => (
  is      => 'ro',
  isa     => enum([$CONF_FROM_ENV,$CONF_FROM_FILE]),
  default => $CONF_FROM_ENV
);

#
# Convenience method for adding dynamic methods to an object
#
sub _add_helper {
  Mojo::DynamicMethods::register __PACKAGE__, @_;
}

#
# Construct path without duplicating path separators via reduction
#
sub _concat_path {
  reduce { local $/=$SLASH; chomp($a); join(($b =~ m|^$SLASH|) ? $EMPTY : $SLASH, $a, $b) } @_
}

#
# Dynamically create methods at instantiation time, corresponding to configutation definition's dpaths
#
sub BUILD {
  my $self = shift;

  foreach my $el (dpath($self->_base)->match($self->_def)) {
    if(ref($el) eq 'HASH') {
      foreach my $def (keys(%$el)) {
        $self->meta->remove_method($def);
        my $path = _concat_path($self->_base, $def); # construct the new directive path by concatenating with our base
        if(exists($el->{$def}->{isa})) { # Detect whether the resulting node is a branch or leaf node (leaf nodes are required to have an "isa" attribute, though we don't (yet) perform type constraint validation)
          # leaf
          my $el = $el->{$def};
          $self->_add_helper($def => sub {
            my @val;
            push(@val, @{dpath($path)->matchr($self->_conf)}); # if the configuration is set in the .conf file, add it to our possible value list (if it's not, this is a noop)
            push(@val, $ENV{$el->{env}}) if(defined($el->{env}) && exists($ENV{$el->{env}})); # if the definition sets an env var name, add its value to our possible value list

            my $priority = defined($el->{priority}) ? $el->{priority} : $self->_priority; #override the global priority with the directive definition's priority, if it's set
            @val = reverse(@val) if($priority eq $CONF_FROM_ENV); # if the priority is Environment, grab from the end of the list, otherwise, take from the front. This way if one or the other value is not populated, we'll still get the value we do have
            push(@val, $el->{default}) if(exists($el->{default})); # once we have the list ordered for preferential value taking, add the default value to the end so we'll get it if nothing else

            return (grep {defined} @val)[0]; 
          } );
        } else {
          # if it's a branch node, return a new Config instance with a new base location, for method chaining (e.g., config->db->pass)
          $self->_add_helper($def => sub { 
            return __PACKAGE__->new(
              _base     => $path,
              _conf     => $self->_conf,
              _def      => $self->_def,
              _priority => $self->_priority
            ) 
          } );
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
    return $self->$dynamic(@args) if($dynamic);
    my $package = ref $self;
    croak qq{Can't locate object method "$method" via package "$package"};
  }
}

1;
