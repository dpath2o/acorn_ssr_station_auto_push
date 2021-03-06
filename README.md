ACORN SeaSonde HF Radar (SSR) Station (radial) Automatic Data Transfer (push)

Long title, simple job: take newly created SeaSonde radial files via hook in 
COS (CODAR Ocean Sensors) proprietary /codar/seasonde/apps/radialtools/spectraprocessing/analyzespectra
and transfer files to a remote server. *IF* the transfer fails then queue the
file for a later attempt.

------------------------------------------------------------------------------

After unpacking this file tar file you'll note the contents:

1.) bash script called 'NewRadial'
2.) perl script called 'seasonde_station_data_transfer_push.pl'
3.) perl module called 'HFR-FileTransfer'

To install these files simply copy 'NewRadial' and 'seasonde_station_data_transfer_push.pl'
into /Codar/SeaSonde/Users/Scripts/

To install the perl module you'll need to make sure that you have the following other
perl modules installed:
Log::LogLite
Net::SFTP::Foreign
File::Find::Rule
Term::ANSIColor
Net::NSCA::Client

Ensure the above modules are installe using something like:
'perl -MCPAN -e "install Net::SFTP::Foreign"', etc.

Then install the HFR::FileTransfer perl module:
'cd HFR-FileTransfer ; perl makefile.pl ; make ; sudo make install ; cd ..'

This will get you rolling and you should now type in 'perldoc HFR::FileTransfer' 
and have a read through the documentation on this module before implementing.  

Of course, once NewRadial file is in /codar/seasonde/users/script directory it will 
effectively be called each /codar/seasonde/apps/radialtools/spectraprocessing/analyzespectra
makes a radial file ... so you'll want to hurry up and read before the next radial is created!

Any problems, questions, comments, concerns, etc. email danielpath2o@gmail.com