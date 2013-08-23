package HFR::FileTransfer;

# Internal Packages
use 5.012003;
use strict;
use warnings;
use File::Basename;
use File::Copy;
use Log::LogLite;
use Data::Dumper;

# Third-party packages
use Net::SFTP::Foreign;
use File::Find::Rule;
use Term::ANSIColor qw(:constants);

our $VERSION = '1.1';

################################################################################

=head1 NAME

HFR::FileTransfer - Transfer HF radar data files to and from remote locations

=head1 SYNOPSIS

use HFR::FileTransfer;

=head2 TWO USES:

=head3 USAGE 1 (SINGLE FILE TRANSFER):

  $xfer = HFR::FileTransfer->new_transfer(
					     source_file           => $sf,
					     remote_host           => $rh,
					     destination_directory => $dd,
					     user                  => $user,
					     verbose               => $verbose,
					     debug                 => $debug );
  $xfer->HFR::FileTransfer::single_push;
  $xfer->HFR::FileTransfer::single_pull;

=head3 USAGE 2 (QUEUED FILE TRANSFER(S)):

  $xfer = HFR::FileTransfer->new_transfer(
					     queued_directory      => $qd,
					     archive_directory     => $ad,
					     remote_host           => $rh,
					     destination_directory => $dd,
					     user                  => $user,
					     verbose               => $verbose,
					     debug                 => $debug );
  $xfer->HFR::FileTransfer::queued_push;

=head1 DESCRIPTION

Complex wrapper around secure copy (scp) routines

In the first the usage the methods C<single_push> and C<single_pull> will attempt to transfer either from or to a remote host whereas the second usage attempts to push files that are listed in a directory.

=head1 REQUIREMENTS

=over 12

=item Net::SFTP::Foreign

See L<Net::SFTP::Foreign>

=item File::Find::Rule

See L<File::Find::Rule>

=item Term::ANSIColor

See L<Term::ANSIColor>

=item File::Basename

See L<File::Basename>

=back

=head1 METHODS

=head2 new_transfer

Initialise the class with the following inputs:

=over 12

=item verbose

show progress/messages to STDOUT

=item debug

Don't actually do anything ... I<not very helpful unless verbose is enabled as well>

=item remote_host

Host name of remote server

=item ssh_key_filen

The local RSA SSH key file.  This must exist on the remote server's C<.ssh/authorized_keys> file for the user one is attempting to login as

=item user

The name of the user on the remote server that one wants to login as

=item source_file

The file name of the single file attempting to be transferred from

=item source_directory

The directory name that the single file exists

=item archive_directory

The directory name that the single might also exist in

=item destination_directory

The directory name of where to transfer the file to

=item destination_file

The file name of the single file attempting to be transferred to

=item queued_directory

The directory name where the queued files will exist

=item queued_suffix

The name that will be appended to each queued file

=item queue_it

Boolean that turns on or off the queuing of failed single file transfers.  Default behaviour is 'on'.

=back

=head2 single_push

Uses C<Net::SFTP::Foreign> to attempt a single file to a remote host.  In the default mode, if the source file cannot be transferred then it is "touched" in a queued directory with a queued suffix name appended to the file name.  Maybe another way to say that, is that an empty file will be created in a directory that is designated as directory for queued files (files to be transferred), which has the same file name as the single file attempting to be transferred and has a suffix attached to the file name to easily establish that the file is just a proxy.  If this not the behaviour you desire and simply want to transfer a file then just add the argument C<< queue_it => 0 >> to the 'new_transfer' method.

=head2 single_pull

Again uses C<Net::SFTP::Foreign> to attempt to grab/pull a file from a remote host to the local machine.  Just as with the single_push method, this method will queue a file that cannot be transferred in the default behaviour.

=head2 queued_push

This method is slightly more complex in that it attempts to transfer the queued files listed in queued directory.  It first attempts to find the actual file in a 'source directory' and if cannot find it there then it will check and 'archive directory'.  Not too much, if any at all, emphasis should be placed on these names 'source directory' and 'archive directory', they are simply assist the author in keeping them straight, but can simply be thought of as directory one and directory two.  So this method first tests to see if the file exists in directory one (source directory) and then tries to find the file (using C<File::Find::Rule>) in directory two (archive directory).  If a successful file transfer takes place then the queued file, which, remember, is just a proxy file, is, B<if> unqueue'ing is enabled, then it will remove the queued file and put a 'sent' file in its place; effectively just rename the queued file such that sent is on the end of it.

U<Note that these sent files, which are zero byte files, will accumulate in the queued directory and will persist in logged messages when verbose is enabled. This may get annoying and I take no responsibility for annoying you.>

=head2 unqueue_it

This method is for turning on of off the unqueue feature without having to invoke the C<new_transfer>.

=cut

################################################################################
sub new_transfer {

   my($class, %args)               = @_;
   my $self                        = bless( {} , $class );
   # BOOLEAN VERBOSITY
   my $verbose                     = exists $args{verbose} ? $args{verbose} : 0;
   $self->{verbose}                = $verbose;
   # BOOLEAN DEBUG
   my $debug                       = exists $args{debug} ? $args{debug} : 0;
   $self->{debug}                  = $debug;
   # ENABLE LOGGING
   my $logit                       = exists $args{logit} ? $args{logit} : 0;
   $self->{logit}                  = $logit;
   # LOG FILE ON ITS OWN
   my $log_file                    = exists $args{log_file} ? $args{log_file} : "$ENV{HOME}/filetransfer.log"; 
   $self->{log_file}               = $log_file;
   # LOG LEVEL
   my $log_level                   = exists $args{log_level} ? $args{log_level} : 6;
   $self->{log_level}              = $log_level;
   # LOG FROM PASSED LOG LITE HASH
   my $logger                      = exists $args{logger} ? $args{logger} : '';
   $self->{logger}                 = $logger;
   # REMOTE SERVER (HOST) NAME OR IP
   my $remote_host                 = exists $args{remote_host} ? $args{remote_host} : '';
   $self->{remote_host}            = $remote_host;
   # SSH KEY FILE
   my $ssh_key_file                = exists $args{ssh_key_file} ? $args{ssh_key_file} : '';
   $self->{ssh_key_file}           = $ssh_key_file;
   # REMOTE SERVER USER NAME
   my $user                        = exists $args{user} ? $args{user} : '';
   $self->{user}                   = $user;
   # SOURCE DIRECTORY
   my $source_directory            = exists $args{source_directory} ? $args{source_directory} : '';
   $self->{source_directory}       = $source_directory;
   # ARCHIVE DIRECTORY
   my $archive_directory           = exists $args{archive_directory} ? $args{archive_directory} : '';
   $self->{archive_directory}      = $archive_directory;
   # FULL FILE NAME
   my $source_file                 = exists $args{source_file} ? $args{source_file} : '';
   $self->{source_file}            = $source_file;
   # DESTINATION
   my $destination_directory       = exists $args{destination_directory} ? $args{destination_directory} : '';
   $self->{destination_directory}  = $destination_directory;
   # FULL FILE NAME
   my $destination_file            = exists $args{destination_file} ? $args{destination_file} : '';
   $self->{destination_file}       = $destination_file;
   # QUEUED DIRECTORY
   my $queued_directory            = exists $args{queued_directory} ? $args{queued_directory} : "$ENV{HOME}/queued";
   $self->{queued_directory}       = $queued_directory;
   # QUEUED SUFFIX
   my $queued_suffix               = exists $args{queued_suffix} ? $args{queued_suffix} : '.queued';
   $self->{queued_suffix}          = $queued_suffix;
   # QUEUE_IT
   my $queue_it                    = exists $args{queue_it} ? $args{queue_it} : 1;
   $self->{queue_it}               = $queue_it;
   # UNQUEUE_IT
   my $unqueue_it                  = exists $args{unqueue_it} ? $args{unqueue_it} : 0;
   $self->{unqueue_it}             = $unqueue_it;
   # TRANSFER SUCCESS
   $self->{transfer_success}       = 0;

   return $self;

 }
################################################################################
sub enable_log {

  my $self        = shift;
  my $log         = new Log::LogLite( $self->{log_file} , $self->{log_level} );
  $self->{logger} = $log;
  return $self;

}
################################################################################
sub mess_norm {

  my $msg  = shift;
  print GREEN, $msg;
  print RESET;

}
################################################################################
sub mess_alert {

  my $msg  = shift;
  print MAGENTA, $msg;
  print RESET;

}
################################################################################
sub mess_err {

  my $msg  = shift;
  print RED, $msg;
  print RESET;

}
################################################################################
sub queue_file {

  my $self = shift;

  my $msg  = "Could not transfer $self->{source_file}\n";
  $self->{logger}->write( $msg , 1 ) if ($self->{logit});
  mess_alert($msg) if ($self->{verbose});

  my ($name,$path,$suffix) = fileparse( $self->{source_file} );
  my $queued_file = sprintf( "%s/%s%s" , $self->{queued_directory},$name,$self->{queued_suffix} );

  $msg = "touched queued file for later transfer attempt: $queued_file\n";
  $self->{logger}->write( $msg , 1 ) if ($self->{logit});
  mess_alert($msg) if ($self->{verbose});

  system( "touch $queued_file" );

  $self->{transfer_success} = 0;

  return $self;

}
################################################################################
sub unqueue_it {

  my $self = shift;

  if( @_ ) { 

    my $unqueue_it = shift;
    $self->{unqueue_it} = $unqueue_it; 

  }

  return $self->{unqueue_it};

}
################################################################################
sub single_push {

  my $self = shift;

  my $rh = $self->{remote_host};
  my $dd = $self->{destination_directory};

  #loop over each remote host
  my $cnt=0;

  my $msg  = "Establishing SSH connection to '$rh' as user '$self->{user}' to transfer into '$dd'\n";
  $self->{logger}->write( $msg , 1 ) if ($self->{logit});
  mess_norm( $msg ) if ($self->{verbose});

  my $sftp = Net::SFTP::Foreign->new(
				     host=>$rh,
				     user=>$self->{user},
				     timeout=>60) unless ( $self->{debug}==1 );

  # queue file if there's a problem with SFTP
  if (!($sftp->error==0) && $self->{queue_it}==1) {

    my $msg = $sftp->error."\n";
    $self->{logger}->write( $msg , $self->{log_level}) if ($self->{logit});
    mess_err( $msg ) if ($self->{verbose});
    $self->{transfer_success} = 0;

  } else {

    my ($name,$path,$suffix) = fileparse( $self->{source_file} );
    $sftp->put( $self->{source_file} , $dd.'/'.$name );

    # queue file if there's a problem with SFTP
    if (!($sftp->error==0) && $self->{queue_it}==1) {

      my $msg = $sftp->error."\n";
      $self->{logger}->write( $msg , $self->{log_level}) if ($self->{logit});
      mess_err( $msg ) if ($self->{verbose});
      $self->{transfer_success} = 0;

    } else {

      $msg = "SUCCESSFUL TRANSFER: $self->{source_file} to $rh:$dd\n";
      $self->{logger}->write( $msg , 1 ) if ($self->{logit});
      mess_norm( $msg ) if ($self->{verbose});
      $self->{transfer_success} = 1;

    }
  }

  if ( !$self->{transfer_success} ) {

    $self->queue_file;

  }
}
################################################################################
sub queued_push {

  my $self = shift;

  # read the queued directory
  opendir DH, $self->{queued_directory};
  my @queued_files = readdir DH;
  closedir DH;

  # loop over each file in the directory
  foreach my $queued_file (@queued_files) {

    # see if the file matches the CODAR standard type of filename format
    if ($queued_file =~ m/^(\w{3}|\w{4})[_](\w{4})[_](\d{4}|\d{2})[_](\d{2})[_](\d{2})[_]?(\d{2})?(\d{2})?(\d{2})?[.]?(\w{3}|\w{4})?$self->{queued_suffix}/i) {

      my $msg = "Attempting to transfer queued_file: $queued_file\n";
      $self->{logger}->write( $msg , 1 ) if ($self->{logit});
      mess_norm( $msg ) if ($self->{verbose});

      # rename file from it's original source directory 
      my ($name,$path,$suffix) = fileparse( $queued_file );
      my @tmp                  = split(/$self->{queued_suffix}/,$name);
      $self->{source_file}     = sprintf( "%s/%s" , $self->{source_directory},$tmp[0] );

      # if the file still exists there then attempt to transfer it again
      if (-e $self->{source_file}) {

	$msg = "$self->{source_file} exists, attempting to transfer file\n";
 	$self->{logger}->write( $msg , 1 ) if ($self->{logit});
	mess_norm( $msg ) if ($self->{verbose});
	$self->single_push;

	# unqueue the file
	if ( $self->{unqueue_it} ) {

	  $msg = "Moving queued file $self->{queued_directory}/$queued_file to $self->{queued_directory}/$tmp[0].sent\n";
	  $self->{logger}->write( $msg , 1 ) if ($self->{logit});
	  mess_norm( $msg ) if ($self->{verbose});
	  move($self->{queued_directory}.'/'.$queued_file,$self->{queued_directory}.'/'.$tmp[0].'.sent') if ( $self->{transfer_success}==1 && $self->{debug}==0 );

	}

      # file does not exist in original source directory
      } else {

	$msg = "$self->{source_file} does not exist\nSearching for $tmp[0] in $self->{archive_directory}\n";
	$self->{logger}->write( $msg , 3 ) if ($self->{logit});
	mess_alert( $msg ) if ($self->{verbose});

	# find file
	my $rule = File::Find::Rule->new;
	$rule->file;
	$rule->name( $tmp[0] );
	my @found_file = $rule->in( $self->{archive_directory} );

	# attempt to transfer first found file
	if ($found_file[0]) {

	  $self->{source_file} = $found_file[0];
	  $self->single_push;

	  # unqueue the file
	  if ( $self->{unqueue_it} ) {

	    $msg = "Moving queued file $self->{queued_directory}/$queued_file to $self->{queued_directory}/$tmp[0].sent\n\n";
	    $self->{logger}->write( $msg , 1 ) if ($self->{logit});
	    mess_norm( $msg ) if ($self->{verbose});
	    move($self->{queued_directory}.'/'.$queued_file,$self->{queued_directory}.'/'.$tmp[0].'.sent') if ( $self->{transfer_success}==1 && $self->{debug}==0 );

	  }

        # queued file was not found in archive directory ... probably should be removed from queued path
	} else {

	  $msg = "$self->{source_file} was not found in $self->{archive_directory}\nConsider removing $self->{source_file} from $self->{queued_directory}\n";
	  $self->{logger}->write( $msg , 6 ) if ($self->{logit});
	  mess_err( $msg ) if ($self->{verbose});

	}
      }
    } else {

	my $msg = "$queued_file does *not* match SeaSonde file naming convection ... skipping\n";
	$self->{logger}->write( $msg , 6 ) if ($self->{logit});
	mess_err( $msg ) if ($self->{verbose});

    }
  }

  return $self;

}
################################################################################
sub single_pull {

  my $self    = shift;

  my $rh = $self->{remote_host};
  my $dd = $self->{destination_directory};

  my $msg  = "Establishing SSH connection to '$rh' as user '$self->{user}' to transfer into '$dd'\n";
  $self->{logger}->write( $msg , 1 ) if ($self->{logit});
  mess_norm( $msg ) if ($self->{verbose});

  my $sftp = Net::SFTP::Foreign->new(
                                     host=>$rh,
                                     user=>$self->{user},
                                     timeout=>60);

  # stop if there's a problem with SFTP
  if (!($sftp->error==0)) {

      my $msg = $sftp->error."\n";
      $self->{logger}->write( $msg , $self->{log_level}) if ($self->{logit});
      mess_err( $msg ) if ($self->{verbose});
      $self->{transfer_success} = 0;

  } else {

      my ($name,$path,$suffix) = fileparse( $self->{source_file} );
      $msg = "ATTEMPTING TRANSFER: $rh:$self->{source_file} to $dd/$name\n";
      $self->{logger}->write( $msg , 1 ) if ($self->{logit});
      mess_norm( $msg ) if ($self->{verbose});
      $sftp->get( $self->{source_file} , $dd.'/'.$name );

      # queue file if there's a problem with SFTP
      if (!($sftp->error==0)) {

	  my $msg = $sftp->error."\n";
	  $self->{logger}->write( $msg , $self->{log_level}) if ($self->{logit});
	  mess_err( $msg ) if ($self->{verbose});
	  $self->{transfer_success} = 0;

      } else {

	  $msg = "-----SUCCESSFUL-----\n";
	  $self->{logger}->write( $msg , 1 ) if ($self->{logit});
	  mess_norm( $msg ) if ($self->{verbose});
	  $self->{transfer_success} = 1;

      }
  }
}
################################################################################

1;
__END__

=head1 Version Notes

=head2 Version 0.1

 First release of software. Non-real-time Testing and verification complete.

=head2 Version 0.2

When implemented in 'real-time' for some unknown reason  C<< Net::SFTP::Foreign->setcwd( $self->{destination_directory} ) >> does not work. The file is still transferred to users home directory, so there is no error reported. I have reported the call sequence and ultimately this behaviour to the maintainer of C<Net::SFTP::Foreign>.

=head2 Version 0.3

Logging feature added

=head2 Version 0.4

Added logging and messaging internal sub routines

=head2 Version 0.5

Completed testing of latest version

=head2 Version 1.0

Added C<single_pull> method. Code version 1.0 ready.

=head2 Version 1.1

Added documentation

=head1 AUTHOR

Daniel Patrick Lewis Atwater, E<lt>danielpath2o@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Daniel Patrick Lewis Atwater

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.12.3 or, at your option, any later version of Perl 5 you may have available.

=cut
