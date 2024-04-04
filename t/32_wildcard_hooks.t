use v5.26;
use warnings;

use Test2::V0;

use Config::Structured;

use experimental qw(signatures);

my $conf;
like(warnings {
  $conf = Config::Structured->new(
    structure => {
      core => {
        assets => {
          isa => 'Str'
        },
        logs => {
          isa => 'Str'
        },
        tmp => {
          isa => 'Str'
        },
      },
      auxiliary => {
        assets => {
          isa => 'Str'
        },
        tmp => {
          isa => 'Str'
        }
      }
    },
    config => {
      core => {
        assets => '/data/assets',
        logs   => '/data/logs',
        tmp    => '/data/tmp',
      },
      auxiliary => {
        assets => '/aux/assets',
        tmp    => '/aux/tmp',
      }
    },
    hooks => {
      '/core/*' => {
        on_load => sub ($path, $value) {
          warn("Directory '$value' does not exist at $path (load)");
        },
        on_access => sub ($path, $value) {
          warn("Touched a core dir");
        }
      },
      '/*/tmp' => {
        on_access => sub ($path, $value) {
          warn("Touched a tmp dir");
        }
      }
    }
  );
  $conf->core;
  $conf->auxiliary->assets;
},
[(qr{Directory '/data/\w+' does not exist at /core/\w+ \(load\)}) x 3,], 'on_load wildcard hook runs');

like(warning {$conf->auxiliary->tmp}, qr{Touched a tmp dir}, "on_access wildcard hook runs");

like(warnings {$conf->core->tmp}, [(qr{Touched a (tmp|core) dir}) x 2], "on_access wildcard hooks run");

done_testing;
