#!/usr/bin/perl

#       perl program to check heartbeat emails for protop clients.
#       if heartbeat email is not received within <delta> minutes of agreed time
#       then send an alert email.

use strict;
use warnings;

# required modules
use Net::IMAP::Simple;
use Email::Simple;
use IO::Socket::SSL;
use Time::Piece;
use Time::Seconds;
use File::Basename;

our $VERSION = '1.00';
our $name = basename($0);

if( int(@ARGV) == 0 || grep( /^(-h|--help)$/i, @ARGV ) ){
   print "\nUsage: $name [options]\nProTop Mail Heartbeat Checker\n\nExample:";
   print "  $name --user username --pass password --subject string --delta 10\n\n";
   print "Mandatory arguments:\n";
   print "  --user username         : The username to log in to IMAP with\n";
   print "  --pass password         : The password to log in to IMAP with\n";
   print "  --subject string        : Text to search for in Subject: header\n";
   print "  --notify emailaddress   : email for contact if message not received\n";
   print "  --delta num             : Minutes to allow +/- run time (now)\n\n";
   print "Optional arguments:\n";
   print "  --passfile file         : An alternative to --pass. File contains the password\n";
   print "  --purge num             : Purges HB emails over num days old\n";
   print "  --host hostname|IP      : Defaults to 127.0.0.1\n";
   print "  --port port             : Defaults to 143 or 993\n";
   print "  --debug                 : Get debugging displays\n\n";
   exit 0;
}



## Parse the arguments
my %options;
{
   my @req = qw( user pass delta subject notify );
   my @opt = qw( host port passfile purge debug );

   my @arg = @ARGV;
   while( @arg ){
      my $key = shift @arg;
      if( $key =~ /^--(.+)$/ ){
         $key = $1;
         die "Bad arg: $key\n" unless grep($key eq $_, @req, @opt, );
         my @values = @{$options{$key}||[]};
         push @values, shift @arg while( int(@arg) && $arg[0]!~/^--/ );
         push @values, 1 unless int(@values);
         $options{$key}=\@values;
      } 
      else {
         die "Bad arg: $key\n";
      }
   }

   if( $options{passfile} ){
      open my $in, '<', $options{passfile}[0] or die $!;
      chomp( my $pass = <$in> );
      $options{pass} = [$pass];
      close $in;
   }

   foreach my $key ( @req ){
      die "Missing required argument: $key\n" unless exists $options{$key};
   }
}


my $user      = $options{user}[0];
my $pass      = $options{pass}[0];
my $delta     = $options{delta}[0];
my $subject   = $options{subject}[0];
my $dashboard = $options{subject}[0];
our $host     = $options{host}[0];
my $debug     = $options{debug}[0];
my $notify    = $options{notify}[0];

my $mhost = exists $options{host} ? $options{host}[0] : '127.0.0.1';
my $mport = exists $options{port} ? $options{port}[0] : 993;


#	Connect
my $imap = Net::IMAP::Simple->new(
    $mhost,
    port => $mport,
    use_ssl => 1,
    ssl_version => 'SSLv23:!SSLv2',
) || die "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";

#	Log in
if ( !$imap->login( $user, $pass ) ) {
    print STDERR "Login failed: " . $imap->errstr . "\n";
    exit(64);
}
#	Look in the the INBOX
my $nm = $imap->select('INBOX');

#	How many messages are there?
my ($unseen, $recent, $num_messages) = $imap->status();
print "unseen: $unseen, recent: $recent, total: $num_messages\n\n";

#	Isolate the messages we want to look at 
my $seekdate = calc_date(-86400);
my $lend = Time::Piece->new;
my $end = $lend->gmtime;
my $start = $end - (60 * $delta * 2);

if ($debug) {print "Start UTC = $start\n  End UTC = $end\n    Delta = +/-$delta minutes\n\n";}

my @ids = $imap->search("SUBJECT $subject SENTSINCE $seekdate" );
my $alive=0;
foreach my $msg (@ids) {
   my $es = Email::Simple->new( join '', @{ $imap->top($msg) } );

   my $maildate  = $es->header('Date');
   $maildate =~ s/([+\-]\d\d):(\d\d)/$1$2/;

   my $mdate = Time::Piece->strptime($maildate,'%a, %d %b %Y %H:%M:%S %z');
   if($debug) {print "Email UTC = $mdate";}
   if ($mdate le $start){ $imap->delete( $msg );}
   if ($mdate ge $start and $mdate le $end){
      $alive=1;
      if ($debug) {print "*";}
   }
   if ($debug) {print "\n";}
}

unless ($alive){
   if ($debug) {print "\nNo heartbeat found for $dashboard - pressing the panic button\n\n";}
   panic_button();
   $imap->quit;
   exit 1;
}

if ($debug) {print "\nHeartbeat record found for: $dashboard  \n\n";}

# Are we purging old emails?
if( $options{purge} ){
   if ($debug) {print "Records to purge:\n";}
   my $purge = $options{purge}[0];
   die "Bad purge: $purge\n" unless $purge =~ /^-?\d+$/;
   my $pdays = begin_date($purge);
   my @ids = $imap->search("SUBJECT $subject BEFORE $pdays");
   foreach my $msg (@ids) {
      my $es = Email::Simple->new( join '', @{ $imap->top($msg) } );
      my $maildate  = $es->header('Date');
      $maildate =~ s/([+\-]\d\d):(\d\d)/$1$2/;
      my $mdate = Time::Piece->strptime($maildate,'%a, %d %b %Y %H:%M:%S %z');
      if ($debug) {print "Email UTC = $mdate\n";}
      $imap->delete( $msg );
   }
}

# Disconnect and exit. The quit also forces an expunge

$imap->quit;

exit;


# subroutines

sub calc_date {

   my $days = $_[0];
   my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
   my( $mday, $mon, $year, ) = ( localtime( time + $days ) )[3..5];
   return sprintf( '%s-%s-%s', $mday, $months[$mon], $year+1900, );
}

sub begin_date {

   my $days = $_[0]-1;
   my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
   my( $mday, $mon, $year, ) = ( localtime( time - ($days*86400) ) )[3..5];
   return sprintf( '%s-%s-%s', $mday, $months[$mon], $year+1900, );
}

sub panic_button {
   my $recipient = $notify;
   my $subject = "[$dashboard] Protop SENDMAIL Alert";
   my $body = "\n Warning: an email heartbeat from $dashboard was not received\n\n";
   open (MAIL, "|mail -s \"$subject\" $recipient");
   print MAIL $body;
   close MAIL;
}

