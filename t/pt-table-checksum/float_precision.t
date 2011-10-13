#!/usr/bin/env perl

BEGIN {
   die "The PERCONA_TOOLKIT_BRANCH environment variable is not set.\n"
      unless $ENV{PERCONA_TOOLKIT_BRANCH} && -d $ENV{PERCONA_TOOLKIT_BRANCH};
   unshift @INC, "$ENV{PERCONA_TOOLKIT_BRANCH}/lib";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use PerconaTest;
use Sandbox;
require "$trunk/bin/pt-table-checksum";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 6;
}

# The sandbox servers run with lock_wait_timeout=3 and it's not dynamic
# so we need to specify --lock-wait-timeout=3 else the tool will die.
my $master_dsn = 'h=127.1,P=12345,u=msandbox,p=msandbox';
my @args       = ($master_dsn, qw(--lock-wait-timeout 3)); 
my $output;

$sb->load_file('master', "t/pt-table-checksum/samples/float_precision.sql");

$output = output(
   sub { pt_table_checksum::main(@args, qw(-t float_precision.t --explain)) },
);

like(
   $output,
   qr/^-- float_precision.t/m,
   "Got output"
);

unlike(
   $output,
   qr/ROUND\(`a`/,
   "No --float-precision, no rounding"
);

$output = output(
   sub { pt_table_checksum::main(@args, qw(-t float_precision.t --explain),
      qw(--float-precision 3)) },
);

like(
   $output,
   qr/^-- float_precision.t/m,
   "Got output"
);

like(
   $output,
   qr/ROUND\(`a`, 3/,
   'Column a is rounded'
);

like(
   $output,
   qr/ROUND\(`b`, 3/,
   'Column b is rounded'
);

like(
   $output,
   qr/ISNULL\(`b`\)/,
   'Column b is not rounded inside ISNULL'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
