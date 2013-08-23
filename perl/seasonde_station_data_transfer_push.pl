#!/opt/local/bin/perl
#
# seasonde_station_data_transfer_push.pl
#
# This perl script is intended to be called for pushing SeaSonde files from the station computer
# to a remote server.
#
# This file uses HFR::FileTransfer module and it's associated modules. I encourage you to read the
# documentation on this module to understand what this script is doing or before modifying this script
# to suit your needs.
#
# Author: Daniel Patrick Atwater
#         Australia Coastal Ocan Radar Network
#         James Cook University
#         email: danielpath2o@gmail.com
#
# Copyright: Open source software, May 2012

use strict;
use DateTime;
use HFR::FileTransfer;
use Getopt::Long;
use Log::LogLite;
use Term::ANSIColor qw(:constants);
use Net::NSCA::Client;

# get datetime
my $dt = DateTime->now;

# initialise and set defaults
#my ($sf,$rh,$dd,$station);
my ($sf,@rh,@dd,$station);
my $ad        = '/codar/seasonde/archives';
my $sd        = '/codar/seasonde/data/radials/measpattern';
my $qd        = "$ENV{HOME}/queued";
my $ssh_key   = "$ENV{HOME}/.ssh/id_rsa";
my $log_file  = sprintf('/codar/seasonde/logs/filetransfer.log');
my $logit     = 0;
my $log_level = 6;
my $queued    = 0;
my $unqueue   = 0;
my $user      = 'codar';
my $verbose   = 0;
my $debug     = 0;
my $help_msg  = 0;

# get input options
my $result = GetOptions (
			 "sf|source_file=s"           => \$sf,
			 "sd|source_directory=s"      => \$sd,
			 "qd|queued_directory=s"      => \$qd,
			 "ad|archive_directory=s"     => \$ad,
			 "rh|remote_host=s"           => \@rh,
			 "dd|destination_directory=s" => \@dd,
			 "ssh_key_file=s"             => \$ssh_key,
			 "logit"                      => \$logit,
			 "log_file=s"                 => \$log_file,
			 "station=s"                  => \$station,
			 "queued"                     => \$queued,
			 "unqueue"                    => \$unqueue,
			 "user"                       => \$user,
			 "v|verbose"                  => \$verbose,
			 "d|debug"                    => \$debug,
                         "h|help!"                    => \$help_msg) or usage("Invalid commmand line options.");

# print usage and exit
usage("Undefined remote host input argument\n\n") if ( !@rh );
usage("Undefined destination directory input argument\n\n") if ( !@dd );
usage("HELP MESSAGE:") if ( $help_msg==1 );

# open the log file
my $log = new Log::LogLite( $log_file , $log_level );

# single file transfer or transfer of queued files
if ( $queued==1 ) {

  # exit here if any of the directories do  not exist
  if ( !(-d $sd) ) {

    my $msg = "Source directory :: $sd\nEither undefined as an input argument OR the directory itself does not exist ... \nexiting $0\n";
    $log->write( $msg , $log_level ) if ($logit);
    err( $msg ) if ($verbose);
    exit;

  }

  if ( !(-d $qd) ) {

    my $msg = "Queued directory :: $qd\nEither undefined as an input argument OR the directory itself does not exist ... \nexiting $0\n";
    $log->write( $msg , $log_level ) if ($logit);
    err( $msg ) if ($verbose);
    exit;

  }

  if ( !(-d $ad) ) {

    my $msg = "Archive directory :: $ad\nEither undefined as an input argument OR the directory itself does not exist ... \nexiting $0\n";
    $log->write( $msg , $log_level ) if ($logit);
    err( $msg ) if ($verbose);
    exit;

  }

  my $xfer = HFR::FileTransfer->new_transfer(
					     source_directory      => $sd,
					     queued_directory      => $qd,
					     archive_directory     => $ad,
                                             remote_host           => \@rh,
                                             destination_directory => \@dd,
					     ssh_key_file          => $ssh_key,
					     log_file              => $log_file,
					     logit                 => $logit,
					     logger                => $log,
					     user                  => $user,
					     unqueue_it            => $unqueue,
					     verbose               => $verbose,
					     debug                 => $debug );
  $xfer->HFR::FileTransfer::queued_push;

} else {

  # exit if file does not exist in source path, if this is true in real-time usage then there
  # is something drastically wrong with SeaSonde software as this is called from a hook within
  # the primary cross spectra to radial processing
  if ( !(-e $sf) ) {

    my $msg = "Source file :: $sf\nEither undefined as an input argument OR the file itself does not exist ... \nexiting $0\n";
    $log->write( $msg , 6 ) if ($logit);
    err( $msg ) if ($verbose);
    exit;

  }

  my $xfer = HFR::FileTransfer->new_transfer(
					     source_file           => $sf,
                                             remote_host           => \@rh,
                                             destination_directory => \@dd,
					     ssh_key_file          => $ssh_key,
					     log_file              => $log_file,
					     logit                 => $logit,
					     logger                => $log,
					     queued_directory      => $qd,
					     user                  => $user,
					     verbose               => $verbose,
					     debug                 => $debug );
  $xfer->HFR::FileTransfer::single_push;

  # specific clause for ACORN Icinga
  if ($xfer->{transfer_success}) {

      my $nsca = Net::NSCA::Client->new(
	  encryption_type => 'xor',
	  remote_host     => '137.219.45.12',
	  );

      $nsca->send_report(
	  hostname        => $station,
	  service         => 'ACORN - data transfer',
	  message         => 'OK - data transfer for ' . $sf . ' successful',
	  status          => $Net::NSCA::Client::STATUS_OK,
	  );

  }
}

#####################################################
sub err {

  my $self = shift;
  my $msg  = shift;
  print RED, $msg;
  print RESET;

}

#####################################################
sub usage {

  # print input message if any
   my $message = $_[0];
   if (defined $message && length $message) {
     $message .= "\n" unless $message =~ /\n$/;
   }

   # name of the script
   my $command = $0;
   $command =~ s#^.*/##;

   print STDERR (
      $message,
      "usage: $command\n".
      "   This script is called in one of two ways:\n".
      "      1.) single file transfer\n".
      "      2.) queued (multiple or single) file transfer\n".
      "      When called with as a single file transfer then here is a simple example of how it might be called:\n".
      "         ./seasonde_station_data_transfer_push.pl --sf='/codar/seasonde/data/radials/measpattern/RDLm_BFCV_2012_01_17_0900.ruv' --rh='foo.com' --dd='/foo/incoming/bfcv' -v\n".
      "      Whereas if it were being called for a multiple file transfer the call would be something like:\n".
      "         ./seasonde_station_data_transfer_push.pl --queued --sd='/codar/seasonde/data/radials/measpattern' --rh='foo.com' --dd='/foo/incoming/bfcv' -v\n\n".
      "      The difference between the single and queued call methods is that the single can be thought of as an explicit way to transfer one file\n".
      "      whereas the queued file method searches for files that have the suffix '.queued' in a queued directory, then attempts to find those files in\n".
      "      in either the 'source directory' or in an 'archive directory'.\n".
      "      The script calls the perl module HFR::FileTransfer to do the work of transferring.\n".
      "      Please see 'perldoc HFR::FileTransfer' for more information, and if you don't have a copy of that module then please email danielpath2o<at>gmail.com\n\n".
      "      \nScript uses Net::NSCA::Client for notification of icinga remote monitoring of a successful file transmission\n".
      "          REQUIRED INPUTS:\n".
      "               --rh|remote_host='seasonde.jcu.edu.au'\n".
      "               --dd|destination_directory='/volumes/data/incoming/bfcv'\n".
      "          OPTIONAL INPUTS:\n".
      "               [--sf|source_file='/codar/seasonde/data/radials/measpattern/rdlm_bfcv_2010_09_30_0000.ruv']\n".
      "               [--sd|source_directory='/codar/seasonde/data/radials/measpattern']\n".
      "               [--ssh_key_file='$ENV{HOME}/.ssh/id_rsa\n".
      "               [--logit]\n".
      "               [--log-file='/codar/seasonde/logs/filetransfer.log']".
      "               [--queued]\n".
      "               [--qd|queued_directory='$ENV{HOME}/queued']\n".
      "               [--ad|archive_directory='/codar/seasonde/archives']\n".
      "               [--user='codar']\n".
      "               [-v] [-d] [-h]\n\n".
      "       sf     :: source full path of file to transfer (single file transfer is assumed)\n" .
      "       sd     :: source directory of the file; default is '/codar/seasonde/data/radials/measpattern'; this is critical when enabling/attempting to transfer queued files\n".
      "       rh     :: remote hostname\n" .
      "       dd     :: destination directory\n".
      "       ad     :: local archive directory; default is '/codar/seasonde/archives'\n".
      "       ssh_key:: SSH RSA key file; default is '$ENV{HOME}/.ssh/id_rsa'\n".
      "       qd     :: queued directory; default is '$ENV{HOME}/queued'\n".
      "       user   :: name of user; default is 'codar'\n".
      "       queued :: turn on queued file transfer\n".
      "       d      :: prevents any copying or moving files; default behaviour: debug on\n".
      "       v      :: verbose\n" .
      "       h      :: print this message and exit\n".
      "\n");
   die("\n")
 }
