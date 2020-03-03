use strict;
use warnings qw(all);
use 5.022;

use Test::More tests => 1;

use Config::Structured;

my $conf = Config::Structured->new(
  structure => <<'END'
{
  file_value => {
    isa => 'Str'
  }
}
END
  , config => <<'END'
{
  file_value => \'t/data/app_password'
}
END
);

is($conf->file_value, 'secure_password123', 'Conf value from referenced file');
