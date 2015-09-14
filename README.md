# Misc
Scripts and hopefully useful stuff

## Utilities

### jira.pl jira cli
This perl script will allow you to query, comment, close and export Jira tickets.

Perl requirements:
use JIRA::Client::Automated;
use Class::CSV;
use Term::ANSIColor;

How to use:
Create a .jira.rc in your home directory with the following information:
```
jiraurl = <your jira url>
juser = <username>
jpass = <password>
```

Help:
```
usage: jira.pl
        -u query tickets in open and in progress state for the comma separated list of users
        -C Close the given ticket (requires -m)
        -c output in csv format
        -m add a comment to the given ticket
        -j search ticket via JQL
        -t ticket number
        -v print ticket details and comments
        -d set debug on (default: off)
        -h Print This help message
```
