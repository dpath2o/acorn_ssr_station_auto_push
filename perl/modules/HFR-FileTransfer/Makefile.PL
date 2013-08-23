use 5.012003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'HFR::FileTransfer',
    VERSION_FROM      => 'lib/HFR/FileTransfer.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/HFR/FileTransfer.pm', # retrieve abstract from module
       AUTHOR         => 'Daniel Patrick Lewis Atwater <dpath2o@local>') : ()),
);
