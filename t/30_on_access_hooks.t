use strict;
use warnings qw(all);
use 5.022;

use Test::More tests => 1;
use Test::Warn;

use Config::Structured;

use experimental qw(signatures);

warning_is {
  my $conf = Config::Structured->new(
    structure => {
      paths => {
        tmp => {
          isa => 'Str'
        }
      }
    },
    config => {
      paths => {
        tmp => '/data/tmp'
      }
    },
    hooks => {
      '/paths/tmp' => {
        on_access => sub ($path, $value) {
          warn("Directory '$value' does not exist at $path (access)");
        }
      }
    }
  );
  $conf->paths->tmp;
}
"Directory '/data/tmp' does not exist at /paths/tmp (access)", 'on_access hook runs';
