use strict;
use warnings qw(all);
use 5.022;

use Test::More tests => 5;
use Test::Warn;

use Config::Structured;

my $conf = Config::Structured->new(
  structure => {
    labels => {
      isa => 'ArrayRef[Str]'
    },
    authz => {
      isa => 'HashRef'
    },
    other => {
      isa => 'Any'
    },
    bad => {
      isa => 'not a valid type'    # [sic] use of invalid type
    }
  },
  config => {
    labels => [qw(a b c)],
    authz  => 'authz value',       # [sic] use of incorrect type
    other  => [],
    bad    => 'abc'
  }
);

is(ref($conf->labels), 'ARRAY', 'Conf value is array');
warning_like {$conf->authz}{carped => qr/[[]Config::Structured\] Value '"authz value"' does not conform to type 'HashRef'/},
  'Conf value is not hash';

# No warning for comparing anything to type Any
warning_is {$conf->other} undef, 'Conf value is any';

warning_like {$conf->bad}{carped => qr/\[Config::Structured\] Invalid typeconstraint '.*'. Skipping typecheck/}, 'Conf type is bad';
{
  local $SIG{__WARN__} = sub { };    # we've already checked this warning, so we suppress it for the next test
  is($conf->bad, 'abc', 'Bad typeconstraint value');
}
