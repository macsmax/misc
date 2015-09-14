#!/usr/bin/perl
use strict;
use warnings;
#http://cpansearch.perl.org/src/FRIMICC/JIRA-Client-Automated-1.01/README
use JIRA::Client::Automated;
use Data::Dumper;
use Getopt::Std;
use Class::CSV;
use Term::ANSIColor;


my $numargv = @ARGV;
my $DEBUG = 0;
my ( $jiraurl, $juser, $jpass, $userslist, @userslistarr, @issues, @reformat, $Ticket, $csv, @csvfields, $message, $ticketno, %Config);
my $DOCSV = 0;
my $Verbouse = 0;
my $Project = "SYS";
my $config_file = glob('~/.jira.rc');


sub parse_config_file {

    my ($config_line, $Name, $Value, $Config, $File);

    #local ($config_line, $Name, $Value, $Config);

    ($File, $Config) = @_;

    unless ( -e $File ) { 
      print "Configuration file missing, please create a config file $File with the following configuration\n\n";
      print "jiraurl = <your jira url>\njuser = <username>\njpass = <password>\n\n";
      print "Make sure that the file is not world readable, as it contains your Jira password!\n";
    
      exit(1);
    
    }
    
    # Check configuration file permission, stop if the file is world readable
    my $mode = (stat($File))[2];
    my $file_mode = sprintf("%04o", $mode & 07777);
    if ($mode & 044 || $mode & 077 || $mode & 055 || $mode & 022) {
      print "the configuration file mode for $File is too open ($file_mode), anyone in the system could read your Jira password, please correct.\n";
      exit(1);
    }

    if (!open (CONFIG, "$File")) {
        print "ERROR: Config file unreadable : $File";
        exit(1);
    }

    while (<CONFIG>) {
        $config_line=$_;
        chop ($config_line);          # Get rid of the trailling \n
        $config_line =~ s/^\s*//;     # Remove spaces at the start of the line
        $config_line =~ s/\s*$//;     # Remove spaces at the end of the line
        if ( ($config_line !~ /^#/) && ($config_line ne "") ){    # Ignore lines starting with # and blank lines
            ($Name, $Value) = split (/=/, $config_line);          # Split each line into name value pairs
	    # strip spaces between "=" and values
	    $Name =~ s/\s$//;
	    $Name =~ s/^\s//;
	    $Value =~ s/\s$//;
	    $Value =~ s/^\s//;
            $$Config{$Name} = $Value;                             # Create a hash of the name value pairs
        }
    }

    close(CONFIG);

}

# Call the subroutine that reads the config file
&parse_config_file ($config_file, \%Config);

$juser = $Config{'juser'};
$jpass = $Config{'jpass'};
$jiraurl = $Config{'jiraurl'};

unless ( $juser && $jpass && $jiraurl ) {
  print "Unable to find user or password credentials or jira url in config file $config_file\n";
  exit(1);
}

sub HELP {
  print <<EOF;
usage: $0 
	-u query tickets in open and in progress state for the comma separated list of users
	-C Close the given ticket (requires -m)
	-c output in csv format
	-m add a comment to the given ticket 
	-j search ticket via JQL
	-t ticket number
	-v print ticket details and comments 
	-d set debug on (default: off)
	-h Print This help message
EOF
    exit 1;
}

# Connect to Jira
my $jira = JIRA::Client::Automated->new("$jiraurl", "$juser", "$jpass");

if ( $numargv gt 0 ) {
  getopts('hdCcm:u:Ct:j:v');
  our ( $opt_d, $opt_m, $opt_h, $opt_C, $opt_c, $opt_u, $opt_t, $opt_j, $opt_v);
  if ($opt_h) {
    &HELP;
    exit 1;
  }
  if ($opt_c) {
    $DOCSV = 1;
  }
  if ($opt_v) {
    $Verbouse = 1;
  }
  if ($opt_d) {
    $DEBUG = 1;
  }
  if ($opt_u) {
    $userslist = $opt_u;
    @userslistarr = split(',', $userslist);
    print Dumper @userslistarr if $DEBUG;
    foreach my $user (@userslistarr) {
      &JqlSearch("status in ('Open', 'In Progress') and assignee = $user", 0);
    }
    exit 0; 
  }
  if ($opt_t) {
    $ticketno = $opt_t;
    unless ($opt_m || $opt_C) {
      &JqlSearch($ticketno, 1);
    }
  }
  if ($opt_j) {
    &JqlSearch($opt_j, 0);
  }
  if ($opt_m) {
    $message = $opt_m;
    unless ($ticketno) {
      print "Missing ticket number\n\n";
      &HELP;
    }
    if ($opt_C) {
      # Closing ticket with message
      print "Closing ticket number $ticketno with comment \n$message\n\n";
      $jira->close_issue($ticketno, "Fixed", $message);
    } else {
      # Add comment to the ticket
      print "Adding comment to ticket number $ticketno\n$message\n\n";
      $jira->create_comment($ticketno, $message);
    }
  }
} else {
  &HELP;
}

# Do the JQL query
sub JqlSearch {
  my $jql = $_[0];
  my $single_get = $_[1];
  if ($single_get) {
    my $issue = $jira->get_issue($jql);
    print Dumper $issue if $DEBUG;
    print "+"."-" x 120 ."+\n" unless ($DOCSV);
    &Jreformat($issue);
    print "+"."-" x 120 ."+\n" unless ($DOCSV);
  } else {
    my @issues = $jira->all_search_results($jql, 1000);
    print Dumper @issues if $DEBUG;
    if (@issues) {
      if ($DOCSV) {
        print "output in CSV format\n" if $DEBUG;
        if ($Verbouse) {
          @csvfields = qw/Ticket Summary Priority Status Assignee Details/;
        } else {
          @csvfields = qw/Ticket Summary Priority Status Assignee/;
        }
        $csv = Class::CSV->new(
        fields         => [@csvfields]
        );
        print join(",", @csvfields)."\n";
      }
      for (my $i=0; $i < @issues; $i++) {
        print "+"."-" x 120 ."+\n" unless ($DOCSV);
        &Jreformat($issues[$i]);
        print "+"."-" x 120 ."+\n" unless ($DOCSV);
      }
    } else {
      print "No issues found\n";
      exit 1;
    }
  }
  return @reformat;
}


# format the output coming from Jira JQL
sub Jreformat {
  my $jarr = $_[0];
  
  if ($jarr) {
    if ($DOCSV) {
      print "output in CSV format\n" if $DEBUG;
        if ($Verbouse) {
          $csv = Class::CSV->new(
          fields         => [qw/Ticket Summary Priority Status Assignee Details/]
          );
          $csv->add_line({
	  	Ticket 		=> $jarr->{'key'},
	  	Summary 	=> $jarr->{'fields'}{'summary'}, 
	  	Priority 	=> $jarr->{'fields'}{'priority'}{'name'}, 
	  	Status 		=> $jarr->{'fields'}{'status'}{'name'},
	  	Assignee 	=> $jarr->{'fields'}{'assignee'}{'name'},
		Details 	=> $jarr->{'fields'}{'description'}
	  });
        } else {
          $csv = Class::CSV->new(
          fields         => [qw/Ticket Summary Priority Status Assignee/]
	  );
          $csv->add_line({
	  	Ticket 		=> $jarr->{'key'},
	  	Summary 	=> $jarr->{'fields'}{'summary'}, 
	  	Priority 	=> $jarr->{'fields'}{'priority'}{'name'}, 
	  	Status 		=> $jarr->{'fields'}{'status'}{'name'},
	  	Assignee 	=> $jarr->{'fields'}{'assignee'}{'name'},
	  });
        }
      $csv->print();
    } else {
      print color 'bold'; print "Ticket:\t\t"; print color 'reset';
      print $jarr->{'key'}." - ". $jiraurl . "/browse/". $jarr->{'key'} ."\n";
      print color 'bold'; print "Summary:\t"; print color 'reset';
      print $jarr->{'fields'}{'summary'}."\n";
      print color 'bold'; print "Priority:\t"; print color 'reset';
      print $jarr->{'fields'}{'priority'}{'name'}."\n";
      print color 'bold'; print "Status:\t\t"; print color 'reset';
      print $jarr->{'fields'}{'status'}{'name'}."\n";
      print color 'bold'; print "Assignee:\t"; print color 'reset';
      print $jarr->{'fields'}{'assignee'}{'name'}."\n";
      if ( $Verbouse ) {
        print color 'bold'; print "Details:\n"; print color 'reset';
        print $jarr->{'fields'}{'description'}."\n\n";
        print color 'bold'; print "Comments:\n"; print color 'reset';
        print "+"."-" x 120 ."+\n" unless ($DOCSV);
	my @comms_arr = $jarr->{'fields'}{'comment'}{'comments'};
	foreach my $comms (@comms_arr) { 
	  foreach my $comms2 (@$comms) {
	    print "Date: ". $$comms2{created} ." - ". $$comms2{author}{displayName} ." (". $$comms2{author}{emailAddress} .")\n";
            if ($$comms2{updated} ne $$comms2{created}) { 
              print "Updated on Date: ". $$comms2{updated} ." - ". $$comms2{updateAuthor}{displayName} ." (". $$comms2{updateAuthor}{emailAddress} .")\n";
            }
            print "\n";
	    print $$comms2{body}."\n";
            print "+"."-" x 120 ."+\n" unless ($DOCSV);
	  }
        }
      }
    }
  } else {
    print "unable to iterate through this issue.\n";
    exit 1;
  }
}
