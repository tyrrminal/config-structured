package Test::Concert::Config;

use base qw(Test::Class);
use Test::More;
use Test::Exception;

use Concert::Config;

#
# Data For Testing
#
sub conf {
  {
    db => {
      user => "dbuser",
      pass => "not_dbpass",
    },
    title => "Config Tester"
  }
}

sub def {
  {
    smtp => {
      host => {
        isa => 'Str',
        env => 'SMTP_HOST'
      },
      port => {
        isa => 'Int',
        env => 'SMTP_PORT'
      }
    },
    notifications => {
      to => {
        isa => 'Str',
        env => 'NOTIFICATIONS_RECIPIENT'
      },
      from => {
        isa => 'Str',
        env => 'NOTIFICATIONS_SENDER'
      }
    },
    db => {
      dsn => {
        isa => 'Str',
        env => 'DB_DSN',
        default => 'localhost'
      },
      user => {
        isa => 'Str',
        env => 'DB_USER',
        default => 'configuser'
      },
      pass => {
        isa => 'Str',
        env => 'DB_PASS',
        priority => 'env'
      }
    },
  }
}
##

sub conf_init : Test(startup => 1) {
  my $test = shift;
  $test->{config} = Concert::Config->new(
    _conf => $test->conf,
    _def  => $test->def
  );

  isa_ok($test->{config},'Concert::Config');
}

sub test_config_file_value : Test(3) {
  my $conf = shift->{config};

  lives_ok(sub { $conf->db });
  lives_ok(sub { $conf->db->user });
  is($conf->db->user, 'dbuser');
}

sub test_unspecified_value : Test(3) {
  my $conf = shift->{config};

  lives_ok(sub { $conf->notifications });
  lives_ok(sub { $conf->notifications->to });
  is($conf->notifications->to, undef);
}

sub test_env_overridden_value : Test(3) {
  my $conf = shift->{config};

  lives_ok(sub { $conf->db });
  lives_ok(sub { $conf->db->pass });
  isnt($conf->db->pass, "not_dbpass");
}

sub test_default_value : Test(3) {
  my $conf = shift->{config};

  lives_ok(sub { $conf->db });
  lives_ok(sub { $conf->db->dsn });
  is($conf->db->dsn, 'localhost');
}

sub test_invalid : Test(1) {
  my $conf = shift->{config};

  dies_ok(sub { $conf->title }, 'title is not in definition');
}

1;
