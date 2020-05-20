#!/usr/bin/perl
#use Inline (Config => DIRECTORY =>  '/var/www/.data');

#use lib '/usr/local/freetds/lib';
use CGI;
use DBI;
use JDBC;
use DBD::Pg;
use DBD::Sybase;
use strict;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use XML::Simple;
use URI::Escape;

# $testing flag is used to block out deployment and decommission writes to live database files while testing other
# servers, since the regular production/development test is done on box name, and currently development is done on
# the same server, just a different directory. It will also determine the setup for the site_transition database,
# since we do have a test area for that system.

our $testing = 0;

my $ignore_ipweb = 1; ##Ignore IP Web: skipped per WR 230282
my $ignore_viaremote = 0;
my $ignore_asset = 1;
my $ignore_wysdm = 0;
my $ignore_dns = 0;
my $ignore_libwatch = 1;
my $ignore_st = 0;
my $comm_distro;
my $dns_distro;
my $subject;
my $message;
my $out_status;
my $update_cep = 0;

our $pg_port = '5432';
my $login_loc = "auto_dep_login.pl";

if ($testing == 1)
        {
        # Those sections you don't need to test, leave at 1. Ones that you want to test, set to zero.
        $ignore_ipweb = 1;
        $ignore_viaremote = 1;
        $ignore_asset = 1;
        $ignore_wysdm = 1;
        $ignore_dns = 1;
        $ignore_libwatch = 1;
        $ignore_st = 0;
        $comm_distro = 'timpar@us.ibm.com, cmbrprt@us.ibm.com';
        $dns_distro = $comm_distro;
        $login_loc = "auto_dep_login_test.pl";
        }
else
        {
        $comm_distro = 'timpar@us.ibm.com';
    $dns_distro = 'timpar@us.ibm.com' #, timpar@us.ibm.com';
        }


#####################################
# KLS 4/30/12 Added login to system #
#####################################

use CGI::Session;
my $query = new CGI;

if ($query->param('sid') eq "")
        {
        print $query->redirect("$login_loc");
        }

#########################################################
#    S E T   U P   S E S S I O N   V A R I A B L E S    #
#########################################################

my $sid = $query->param('sid');
my $session = new CGI::Session(undef, $sid, {Directory=>'/usr/tmp'});

my $uid = $session->param('uid');
my $pw = $session->param('pw');

if ($uid eq "" or $pw eq "")
        {
        print $query->redirect("$login_loc");
        }

##############
# End of Mod #
##############

my $ua = LWP::UserAgent->new;
my $server_name = `/bin/uname -n`; # find out production or dev
chomp($server_name);
    # for ViaRemote
   my $db_name;
   my $db_host;
   my $db_user;
   my $db_pass;
   my $host;
    # for ipweb
   my $db_name_ipw;
   my $db_host_ipw;
   my $db_user_ipw;
   my $db_pass_ipw;
   my $host_ipw;
    # for ticketing system SDE
   my $db_name_sde;
   my $db_host_sde;
   my $db_user_sde;
   my $db_pass_sde;
   my $host_sde;
    # for Mediation
   my $db_name_medi;
   my $db_host_medi;
   my $db_user_medi;
   my $db_pass_medi;
   my $host_medi;
   my $dbh_medi;

   # for Site Transition - added 4/5/12 KLS
   my $db_name_st;
   my $db_host_st;
   my $db_user_st;
   my $db_pass_st;
   my $db_schema_st;
   my $host_st;

# set env for production or dev
if ( $server_name eq 'webapps' )
        {
        $db_name="viaremotecap";
        #   $db_host="storageops1.arsenaldigital.com";
        $db_host="postgresdbs.bcrs-vaults.ibm.com";
        #       $db_user="viaremotecap";
        $db_user="site_admin";
        #       $db_pass="v18r3m0t3c8p";
        #       $db_pass="viaremotecap";
        $db_pass="site_admin";
        $host = $db_host;

        # for ticketing system SDE
        $db_name_sde="SDE";
        #    $db_host_sde="arsenalsql1.arsenaldigital.com";
        $db_host_sde="sdesql";
        $db_user_sde="readonly";
        $db_pass_sde='C0gn0$14!';
        $host_sde = $db_host_sde;

        # for Mediation
        $db_name_medi = "pmedi";
        $db_user_medi = "readonly";
        $db_pass_medi = "pass1234";

        # for ipweb
        $db_name_ipw = "adswipdb";
        $db_host_ipw = "postgresdbs";
        $db_user_ipw = "ipadmin";
        $db_pass_ipw = "1p8dm1n";
        $host_ipw = $db_name_ipw;
        } # end if $server_name
else
        {
        $db_name="viaremotecap";
        $db_host="postgresdbs";
        $db_user="viaremotecap";
        $db_pass="viaremotecap";
        $host = $db_host;

        # for ticketing system SDE
        $db_name_sde="SDE";
        $db_host_sde="localhost";
        $db_user_sde="readonly";
        $db_pass_sde="ylnodaer";
        $host_sde = $db_host_sde;
} # end else

my $prog_name ="https://deploy.bcrs-vaults.ibm.com/auto_deploy.pl";

# Setup for Site Transition system - based on the $testing field.
if ($testing == 1)
        {
        $db_name_st     = "site_transition";
        $db_host_st     = "postgresdbs.bcrs-vaults.ibm.com";
        $db_user_st     = "site_admin_test";
        $db_pass_st     = "abcd1234";
        $db_schema_st   = "dbotest";
        $prog_name="https://deploy.bcrs-vaults.ibm.com/auto_deploy_test.pl";
        }
else
        {
        $db_name_st     = "site_transition";
        $db_host_st     = "postgresdbs.bcrs-vaults.ibm.com";
        $db_user_st     = "site_admin";
        $db_pass_st     = "site_admin";
        $db_schema_st   = "dbo";

        }
##############
# End of Mod #
##############

my $html = new CGI;
my $LOGFILE = "/var/www/sites/deploy/log/autodeploy.log";

my $host_name = $html->param('SearchHost');
my $SearchHostButton = $html->param('SearchHostButton');
my $exact_match = $html->param('exact_match');
my $Deploy = $html->param('Deploy');
my $Decommission = $html->param('Decommission');
my $libwatch = $html->param('libwatch');

my $sitetrans = $html->param('sitetrans');

my @paramlist = $html->param;

   # for viaremote
my $dbh = DBI->connect("DBI:Pg:database=$db_name;host=$db_host;port='$pg_port'", "$db_user",
          "$db_pass", {PrintError => 1, RaiseError => 0, AutoCommit => 1});
  # SQLServer connection
my $dbh_sde = DBI->connect("dbi:Sybase:server=SDE", "$db_user_sde", "$db_pass_sde", {PrintError => 1});

#-> add to auto_deploy_log
my $this_time = make_time_stamp();
my $log_opr = "Query";
my $new_site_id = "";

if ($Deploy eq 'Deploy')
        {
        $log_opr = "Deploy";
        $new_site_id = $html->param('host_name');
        }
if ($Decommission eq 'Decommission')
        {
$log_opr = "Decommission";
        $new_site_id = $html->param('host_name');
        }
if ($SearchHostButton eq 'Search')
        {
        $log_opr = "Search";
        $new_site_id = $html->param('SearchHost');
        }

my $log_sql;

if ($log_opr eq "Query")
        {
        $log_sql = "insert into $db_schema_st.auto_deploy_log " .
                "(user_id, " .
                "datetime, " .
                "operation) " .
                " values " .
                "('$uid', " .
                "'$this_time', " .
                "'$log_opr')" ;
        }

else
        {
        $log_sql = "insert into $db_schema_st.auto_deploy_log " .
                "(user_id, " .
                "datetime, " .
                "operation, " .
                "device_name) " .
                " values " .
                "('$uid', " .
                "'$this_time', " .
                "'$log_opr', " .
                "'$new_site_id')" ;
        }

$host_st =  DBI->connect("DBI:Pg:database=$db_name_st;host=$db_host_st;port='$pg_port'", "$db_user_st","$db_pass_st", {PrintError => 1, RaiseError => 0, AutoCommit => 1});
my $new_site_id = $html->param('host_name');

my $log_result = $host_st->do($log_sql);

die "Unable for connect to server $DBI::errstr"
    unless $dbh_sde;

#my $dsn="dbi:JDBC:hostname=10.1.10.35:1523;url=jdbc:sqlserver://sdesql.bcrs-vaults.ibm.com:1488;instanceName=SDE;databasename=SDE;ssl=require";
#my $dsn="dbi:JDBC:hostname=10.1.10.35:1523;url=jdbc:sqlserver://arsenalsql1.arsenaldigital.com:1488;instanceName=arsenalsde;databasename=SDE;ssl=require";
#my $dbh_sde = DBI->connect("$dsn", "$db_user_sde", "$db_pass_sde", {PrintError => 1});
#    die "Unable for connect to server $DBI::errstr"
#    unless $dbh_sde;

   # mediation \ oracle database.
        # 10/23/14 KLS Removed connection to mediation
        #
   #if ( !($dbh_medi = DBI->connect("dbi:Oracle:$db_name_medi", "$db_user_medi", "$db_pass_medi", {RaiseError => 0})) ) {
   #   my $err_msg = $DBI::errstr;
   #   print "Cannot connect to database $db_name_medi\nError: $err_msg\n";
   #} # end if

$dbh_sde->do("use SDE") or die $DBI::errstr;

system "touch $LOGFILE" unless -e $LOGFILE;

print $html->header;
print $html->start_html(-title=>'Deployment Automation',-style=>{'src'=>'../css/ibm.css'} );
print $html->start_form(-name=>"deploymentautomation",-action=>"$prog_name",-method=>"POST");

if ($query->param('Submit_attrib_list'))
        {
        print 'Run the attribute creating program<br>';
    my $max_id = $html->param('max_id');
    my $param_list = "";

    for (my $x=1; $x<=$max_id; $x++)
        {
        my $param_name = 'group' . $x . '_input';
        $param_list = $param_list . $x . "," if $html->param($param_name) gt "";
        }

    my $ok = &create_site_attribs($param_list, $html->param('new_site_id'));

        }

# KLS if we are testing, show what tests are being ignored right at the top of the page.
if ($testing==1)
        {

        print "Parameter list: <br>";
        foreach (@paramlist)
        {
        print "$_ = " . $html->param("$_") . "<br>";
        }

        my @bgcolor = ('green','red');

        print "log_sql = $log_sql<br>";
        print "<table bgcolor=\"silver\" align=\"center\" width=\"200\" border=\"1\"><tr><th colspan=2>TESTING MODE:</th>\n",
                "<tr><td bgcolor=\"$bgcolor[$ignore_ipweb]\">\$ignore_ipweb</td><td  bgcolor=\"$bgcolor[$ignore_ipweb]\">$ignore_ipweb</td></tr>\n",
                "<tr><td bgcolor=\"$bgcolor[$ignore_viaremote]\">\$ignore_viaremote</td><td bgcolor=\"$bgcolor[$ignore_viaremote]\">$ignore_viaremote</td></tr>\n",
                "<tr><td bgcolor=\"$bgcolor[$ignore_asset]\" >\$ignore_asset</td><td bgcolor=\"$bgcolor[$ignore_asset]\">$ignore_asset</td></tr>\n",
                "<tr><td bgcolor=\"$bgcolor[$ignore_wysdm]\">\$ignore_wysdm</td><td bgcolor=\"$bgcolor[$ignore_wysdm]\">$ignore_wysdm</td></tr>\n",
                "<tr><td bgcolor=\"$bgcolor[$ignore_dns]\">\$ignore_dns</td><td bgcolor=\"$bgcolor[$ignore_dns]\">$ignore_dns</td></tr>\n",
                "<tr><td bgcolor=\"$bgcolor[$ignore_libwatch]\">\$ignore_libwatch</td><td bgcolor=\"$bgcolor[$ignore_libwatch]\">$ignore_libwatch</td></tr>\n",
                "<tr><td bgcolor=\"$bgcolor[$ignore_st]\">\$ignore_st</td><td bgcolor=\"$bgcolor[$ignore_st]\">$ignore_st</td></tr></table><br>\n";
        }
# EOM

print "<h3 align=\"center\">ADDED FEATURE: You are now able to add the ILO address to the DNS deployment. Click on the \"Make ILO DNS Record\" checkbox next to the new ILO address before clicking on the \"Deploy\" button</h3>";
print "<h3 align=\"center\">NOTICE: You will need to check the \"Update Site Trans\" checkbox to create a Site Transition record</h3>";
print "<table border=0>\n";
print "<tr><td>\n";
print $html->p("Please enter a host name to search:");
print "<input type=\"hidden\" name=\"sid\" value=\"$sid\">\n";
print $html->textfield(-name=>'SearchHost', -value=>"$host_name"),$html->checkbox(-name=>'exact_match',-value=>'1',-label=>'Exact Match');
print "<tr><td>".$html->submit(-value=>'Search',-name=>'SearchHostButton');
print "</table>\n";
print $html->end_form();
print $html->hr();

if ( $Deploy )
        {
        my $ret = 0;
        my $FAILED = 0;
        chomp(my $now = `date +"\%Y/\%m/\%d \%k:\%M:\%S"`);
#   print LOGFL "**** DEPLOY START ****\n";
#   print LOGFL "----------------------\n";
#   print LOGFL "Deploy started at $now for $host_name\n";
        if ($testing==1)
                {
                system("echo '** SYSTEM TEST RUN **' >> $LOGFILE");
                }

        system("echo '**** DEPLOY START ****' >> $LOGFILE");
        system("echo '----------------------' >> $LOGFILE");
        system("echo 'Deploy started at $now for $host_name' >> $LOGFILE");

        if ($ignore_ipweb == 0)
                {
                #$ret=&check_ipweb();
                #if($ret == 1){ $FAILED = 1; }
                }
        else
                {
                print "IPWeb update skipped<br>";
                system("echo 'IP Web Update Skipped' >> $LOGFILE");
                }

        if ($ignore_viaremote == 0)
                {
                $ret=&viaremote_update();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'ViaRemote Deploy failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "ViaRemote update skipped<br>";
                system("echo 'ViaRemote update skipped' >>$LOGFILE");
                }

        if ($ignore_asset == 0)
                {
                $ret=&update_asset();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'Asset update failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "Asset update skipped<br>";
                system("echo 'Asset update skipped' >> $LOGFILE");
                }

        if ($ignore_wysdm == 0)
                {
                $ret=&wysdm_update();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'Wysdm update failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "Wysdm update skipped<br>";
                system("echo 'Wysdm update skipped' >> $LOGFILE");
                }

        if ($ignore_dns  == 0)
                {
                $ret=&update_dns();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'DNS update failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "DNS update skipped<br>";
                system("echo 'DNS update skipped' >> $LOGFILE");
                }

        # LibWatch is dead - thus, killing the call #
        #if ($ignore_libwatch == 0)
        #       {
        #       if ( $libwatch ) {
        #               $ret=&update_libwatch('ADD');
        #               if($ret == 1){ $FAILED = 1; }
        #               }
        #       }
        #else
        #       {print "LibWatch update skipped<br>";}

        print "sitetrans value: $sitetrans<br>\n" if $testing == 1;

        my $update_st = 0;
        if ($sitetrans == 1)
                {$update_st = 1;}
        if ($ignore_st == 0 and $update_st == 1)
                {
                $ret = &deploy_st();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'Site Transition update failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "Site Transition update skipped<br>";
                system("echo 'Site Transition update skipped' >> $LOGFILE");
                }


        $out_status = $FAILED == 0  ? "Passed" : "Failed";

        $subject = "Site $new_site_id deployed";

        $message = "Site $new_site_id has been deployed by user $uid at " .
                make_time_stamp() .
                "  Final status: $out_status";

        print "<h4>Calling email program</h4>" if $testing==1;

        my $ok = send_comm_email($subject, $message, $comm_distro);

        print "<h4>Out of email program</h4>" if $testing==1;
        if($FAILED == 1)
                {
                &send_failure_notice();
                }
        } # end if
elsif ( $Decommission )
        {
        my $ret = 0;
        my $FAILED = 0;
        chomp(my $now = `date +"\%Y/\%m/\%d \%k:\%M:\%S"`);
#   print LOGFL "**** DECOM START ****\n";
#   print LOGFL "----------------------\n";
#   print LOGFL "Decom started at $now for $host_name\n";
        if ($testing==1)
                {
                system("echo '** SYSTEM TEST **' >> $LOGFILE");
                }

        system("echo '**** DECOM START ****' >> $LOGFILE");
        system("echo '----------------------' >> $LOGFILE");
        system("echo 'Decom started at $now for $host_name' >> $LOGFILE");

        if ($ignore_ipweb == 0)
                {
                #$ret=&update_ipweb();
                #if($ret == 1){ $FAILED = 1; }
                }
        else
                {
                print "Decommission in ipweb ignored<br>";
                system("echo 'Decommission in ipweb ignored' >> $LOGFILE");
                }

        if ($ignore_viaremote == 0)
                {
                $ret=&viaremote_decomp();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'Decommission in ViaRemote failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "Decommission in viaremote ignored<br>";
                system("echo 'Decommission in viaremote ignored' >> $LOGFILE");
                }

        if ($ignore_wysdm == 0)
                {
                $ret=&wysdm_decomp();
                if($ret == 1){ $FAILED = 1; }
                }
        else
                {
                print "Decommission in wysdm ignored<br>";
                }

        if ($ignore_asset == 0)
                {
                $ret=&decom_asset();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'Decommission in asset system failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "Decommission in assets ignored<br>";
                system("echo 'Decommission in assets ignored' >> $LOGFILE");
                }

        if ($ignore_dns == 0)
                {
                $ret=&decomp_dns();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'Decommission in DNS failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "Decommission in dns ignored<br>";
                system("echo 'Decommission in DNS ignored' >> $LOGFILE");
                }

        #if ($ignore_libwatch == 0)
        #       {
        #       if ( $libwatch )
        #               {
        #               print $html->p("In Decomm");
        #               $ret=&update_libwatch('DEL');
        #               if($ret == 1){ $FAILED = 1; }
        #               }
        #       }
        #else
        #        {
        #        print "Decommission in libwatch ignored<br>";
        #        }

# 9/11/12 KLS added decommission for site transition

        if ($ignore_st == 0)
                {
                $ret = &decomm_st();
                if($ret == 1)
                        {
                        $FAILED = 1;
                        system("echo 'Site Transition decommission failed' >> $LOGFILE");
                        }
                }
        else
                {
                print "Site Transition decommission skipped<br>";
                system("echo 'Site Transition decommission skipped' >> $LOGFILE");
                }

#   $ret=&decom_bladelogic();
#   if($ret == 1){ $FAILED = 1; }

        $out_status = $FAILED == 0  ? "Passed" : "Failed";

        $subject = "Site $new_site_id decommissioned";

        $message = "Site $new_site_id has been decommissioned by user $uid at " .
                make_time_stamp() .
                "\n  Final status: $out_status";

        print "<h4>Calling email program</h4>" if $testing==1;

        my $ok = send_comm_email($subject, $message, $comm_distro);

        print "<h4>Out of email program</h4>" if $testing==1;


        if($FAILED == 1)
                {
                &send_failure_notice();
                }
        } # end elsif

 if ( $SearchHostButton eq 'Search' ) {
#     `touch $LOGFILE` unless -e $LOGFILE;
#     open(LOGFL, ">> $LOGFILE");
#    my $q1='select "ADSW-Machine Name","Asset IP","Asset TYpe","Asset Description" ';
#    $q1=$q1.'from "ACS"."Inventory Items" ';
#     if ( $exact_match ) {
#        $q1=$q1.'where "ADSW-Machine Name" = '."'$host_name'";
#     } # end if
#     else {
#        $q1=$q1.'where "ADSW-Machine Name" like '."'%$host_name%'";
#     } # end else
        my $q1='select "ADSW-Machine Name","Asset IP","Asset TYpe","Asset Description",b."Company Name", b."ADSW-PRODUCTNAME" ';
        $q1=$q1.', a."ADSW-OUTOFBANDIP", a."Sequence" ';
        $q1=$q1.'from "_SMDBA_"."Inventory Items" a, ';
        $q1=$q1.'"_SMDBA_"."Configurations" b ';
        $q1=$q1.'where a."Seq.Configuration" = b."Sequence" ';

        if ( $exact_match )
                {
                $q1=$q1.'and "ADSW-Machine Name" = '."'$host_name'";
                } # end if
        else
                {
                $q1=$q1.'and "ADSW-Machine Name" like '."'%$host_name%'";
                } # end else

        #    print "<h1>SQL: $q1 <br></h1>\n";
        #
        my $sth = $dbh_sde->prepare($q1);
        $sth->execute() or die print $html->p($DBI::errstr);
        print "<table border=1 cellpadding=0 cellspacing='0')\n";
        print "<tr><th align='left'>Host</th><th align='left'>IP</th>" ,
                "\t<th align='left'>Type</th>",
                "\t<th align='left'>Description</th>" ,
                "\t<th align='left'>OS</th>",
                "\t<th align='left'>Site Transition</th>",
                #"\t<th align='left'>Libwatch</th>",
                "\t<th align='left'>ILO</th>",
                "\t<th colspan='2' align='center'>Action</th></tr>\n";

        my $hl = 1;

        while ( my($machine,$ip,$type,$description,$pid,$product,$management_ip,$seq) = $sth->fetchrow_array() )
                {

                $hl = 1 - $hl;
                my $row_color = ($hl == 1) ? "#98B1C4" : "#C8D7E3";

                # get 3 char partner id

                # 10/23/14 KLS remove partner ID lookup from Mediation
                my $partner_id = 'NNN';

                #my $medi="select partner_abbr from mediation.partner where partner_name = '$pid' \n";
                #my $sth_medi = $dbh_medi->prepare($medi);
                #$sth_medi->execute();
                #my ($partner_id) = $sth_medi->fetchrow_array();
                #$sth_medi->finish();
                #if ( !$partner_id )
                #       {
                #       $partner_id = 'NNN';
                #       &send_email("Partner ID not found","IP: $ip, Host: $machine\n\n$medi\n");
                #       }

                # EOM
                #
                print $html->start_form(-name=>"deploymentautomation",-action=>"$prog_name",-method=>"POST");
                print "\n\t",$html->hidden(-name=>'host_name',-value=>"$machine"),
                        "\n\t",$html->hidden(-name=>'ip_addr',-value=>"$ip");
                print "\n\t",$html->hidden(-name=>'type',-value=>"$type"),"\n\t",
                        $html->hidden(-name=>'description',-value=>"$description");
                print "\n\t",$html->hidden(-name=>'pid',-value=>"$pid"),"\n\t",
                        $html->hidden(-name=>'partner_id',-value=>"$partner_id");
                print "\n\t",$html->hidden(-name=>'product',-value=>"$product"),"\n\t",
                        $html->hidden(-name=>'management_ip',-value=>"$management_ip");
                $html->param(-name=>'sequence',-value=>$seq);

                print "\t<tr bgcolor = \"$row_color\" class='tr_hover'>\n\t\t<td>$machine<td>\n\t\t$ip<td>\n\t\t$type<td>\n\t\t$description\n";
                print "\t\t<td><select name='OS' class='button'>";
                print "\n\t\t\t<option value='0'>OS select";
                print "\n\t\t\t<option>Windows";
                print "\n\t\t\t<option>Linux";
                print "\n\t\t\t<option>Solaris";
                print "\n\t\t\t<option>AIX";
                print "\n\t\t\t<option>Other";
                print "\n\t\t</select></td>\n";
                print "\n\t\t<td>", $html->checkbox(-class=>'button',-name=>'sitetrans',-value=>'1',-label=>'Update Site Trans'), "</td>\n";
                #->KLS Add ILO Address
                if ($management_ip>"")
                        {print "<td align=\"right\">$management_ip <input name=\"Make_ILO\" value=\"Make_ILO\" type=\"checkbox\"> Make ILO DNS Record</td>";}
                else
                        {print "<td></td>"};

                if (is_valid_ip($ip) == 1)
                        {
                        print "\t<td align='center'>",$html->submit(-class=>'button',-name=>'Deploy',-value=>'Deploy'), "</td>\n";
                        print "\t<td align='center'> ",$html->submit(-class=>'button',-name=>'Decommission',-value=>'Decommission'), "</td>\n";
                        }
                else
                        {
                        print "\t<td align=\"center\" colspan=\"2\">Invalid or empty IP Address</td>";
                        }

                print "\t</td></tr>\n";
                print "\t<input type=\"hidden\" name=\"sid\" value=\"$sid\">\n";

                print $html->end_form();
                } # end while
        print "</table>\n";
        } # end if

#close(LOGFL);
$dbh->disconnect();
$dbh_sde->disconnect();
#$dbh_medi->disconnect();

print $html->end_html();
###################################################################################################################################################
sub update_libwatch {
   my ($action) = @_;
   my $host_name =  $html->param('host_name');
   my $url = "http://storageops1:5080/cgi-bin/libwatch_deploy.pl";

   print $html->p("Updating Libwatch for Host: $host ");
#   print LOGFL "Updating Libwatch for Host: $host\n";
#   print LOGFL "See log file on libwatch server for more details\n";
   system("echo 'Updating Libwatch for Host: $host' >> $LOGFILE");
   system("echo 'See log file on libwatch server for more details' >> $LOGFILE");

    #$ua->post( $url, IP=>"$ip_addr",HOSTNAME=>"$host_name",SubmitButton=>'ADD' )
    my $req = POST "$url", [HOST_NAME=>"$host_name",TASK=>"$action"];

    my $res = $ua->request($req);

#    my $test = $ua->content($req);
#    print $html->p("Libwatch: $test");


} # end sub update libwatch
###################################################################################################################################################
sub decom_bladelogic {
   my $host_name = lc($html->param('host_name'));

   print $html->p("Removing $host_name from BladeLogic ");
   system("echo 'Removing $host_name from BladeLogic' >> $LOGFILE");
#   system("echo 'Setting ENVIRONMENT property to DECOM' >> $LOGFILE");
   chomp(my $blres = `/usr/nsh/bin/blcli -a 10.1.0.33 -i /usr/nsh/bin/bladmin_info.dat -r BLAdmins Server decommissionServer $host_name`);

   if($blres){
      print $html->p("Decom of $host_name in BladeLogic succeeded");
      system("echo 'Decom of $host_name in BladeLogic succeeded' >> $LOGFILE");
   } else {
      print $html->p("Decom of $host_name in BladeLogic failed");
      system("echo 'Decom of $host_name in BladeLogic failed' >> $LOGFILE");
   }
} #end decom_bladelogic sub
###################################################################################################################################################
sub update_bladelogic {
   my $host_name = lc($html->param('host_name'));
   my $partner_id = $html->param('partner_id');
   my $ip = $html->param('ip_addr');
   my $SUBNET = "255.255.255.0";
   my $LOGHOST = "10.1.0.20";
   my $SVC = "";
   my $ln;
   my $num = int(rand time());
   my $outfl = $num . ".csv";
   my $logfl = "/var/log/autodeploy_bl.log";
   my($O1,$O2,$O3,$O4) = split('\.',$ip,4);
   my $NET = $O1 . "." . $O2 . "." . $O3 . ".0";

   my $BADEXP = "\-TLIB|\-NBDD|\-AXDD";
   my $hostlen;

   my @fields = split('-',$host_name);

   if($#fields == 1){
      $hostlen = 0;
   } else {
      $hostlen = 1;
   }

   if($hostlen == 1){
      if($host_name !~ /$BADEXP/i){
         my $BLHDR = "NAME,IP_ADDRESS,SUBNET_MASK,NETWORK_ADDRESS,ARSENAL_SERVICE,LOGHOST,VM_VIRTUAL_MACHINE";
         if($host_name =~ /nbma/i){
            $SVC = "ViaBack";
            $ln = "$host_name,$ip,$SUBNET,$NET,$SVC,$LOGHOST,false";
         } elsif ($host_name =~ /axss/i){
            $SVC = "ViaRemote";
            $ln = "$host_name,$ip,$SUBNET,$NET,$SVC,$LOGHOST,false";
         } elsif ($host_name =~ /axms/i){
            $SVC = "ViaRemote";
            $ln = "$host_name,$ip,$SUBNET,$NET,$SVC,$LOGHOST,false";
         } else {
           $BLHDR = "NAME,IP_ADDRESS,SUBNET_MASK,NETWORK_ADDRESS,LOGHOST,VM_VIRTUAL_MACHINE";
            $ln = "$host_name,$ip,$SUBNET,$NET,$LOGHOST,false";
#            print LOGFL "could not determine server function and service offering\n";
#            print LOGFL "Please correct this in BladeLogic after the deployment is complete\n";
            system("echo 'could not determine server function and service offering' >> $LOGFILE");
            system("echo 'Please correct this in BladeLogic after the deployment is complete' >> $LOGFILE");
         }
         print $html->p("Hostname good. Updating BladeLogic");
#         print LOGFL "Hostname good. Updating BladeLogic\n";
         system("echo 'Hostname good. Updating BladeLogic' >> $LOGFILE");
         open(OUT, "> /var/tmp/bladelogic/$outfl");
         print OUT "$BLHDR\n";
         print OUT "$ln\n";
         close(OUT);

         print $html->p("updating BladeLogic for $host_name");
#         print LOGFL "updating BladeLogic for $host_name\n";
         system("echo 'updating BladeLogic for $host_name' >> $LOGFILE");
         chomp(my $blres = `/usr/nsh/bin/blcli -a 10.1.0.33 -i /usr/nsh/bin/bladmin_info.dat -r BLAdmins Server bulkAddServers /var/tmp/bladelogic $outfl US-ASCII false`);

         if($blres =~ /$host_name/){
            print $html->p("Update of BladeLogic succeeded");
#            print LOGFL "Update of BladeLogic succeeded\n";
            system("echo 'Update of BladeLogic succeeded' >> $LOGFILE");
            system("mv /var/tmp/bladelogic/$outfl /var/tmp/bladelogic/completed");
            return 0;
         } else {
            print $html->p("Update of BladeLogic failed");
#            print LOGFL "Update of BladeLogic failed\n";
            system("echo 'Update of BladeLogic failed' >> $LOGFILE");
            system("mv /var/tmp/bladelogic/$outfl /var/tmp/bladelogic/failed");
            return 1;
         }
      } else {
         print $html->p("hostname contains a bad suffix. Skipping BladeLogic update");
#         print LOGFL "hostname contains a bad suffix. Skipping BladeLogic update for host $host_name\n";
        system("echo 'hostname contains a bad suffix. Skipping BladeLogic update for host $host_name' >> $LOGFILE");
            return 1;
      }
   } else {
      print $html->p("hostname too short - expected 5 fields, got 2. Skipping update of BladeLogic");
#      print LOGFL "hostname too short - expected 5 fields, got 2. Skipping update of BladeLogic for host $host_name\n";
      system("echo 'hostname too short - expected 5 fields, got 2. Skipping update of BladeLogic for host $host_name' >> $LOGFILE");
   }

} #end update_bladelogic sub
###################################################################################################################################################
sub update_asset {
   my $host = $html->param('host_name');
   my $status = "Production";


#   print LOGFL "Setting status of $host to $status in asset system\n";
   system("echo 'Setting status of $host to $status in asset system' >> $LOGFILE");
      my $url = "http://sdebldr/SDEWebServices/set_asset_status.asmx/Execute";
#    my $req = POST "$url", [HOST_NAME=>"$host_name",TASK=>"$action"];

    my $res = $ua->request(POST "$url", [ host => "$host", status => "$status"]);
#   system("echo 'curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'POSTVAR=$assetrec' -v http://ipsms/XmlPostHandler/autodeploy.post >> $LOGFILE");
#   system("curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'POSTVAR=$assetrec' -v http://ipsms/XmlPostHandler/autodeploy.post >> /var/log/assetupdate.log");
} #close update_asset sub
###################################################################################################################################################
sub decom_asset {
   my $host = $html->param('host_name');
#   my $status = "In Inventory/Storage";
   my $status = "Decommed - Awaiting Transit";

#   print LOGFL "$seq|$host|$status\n";
   system("echo '$host|$status' >> $LOGFILE");

#   print LOGFL "Setting status of $host to $status in asset system\n";
   system("echo 'Setting status of $host to $status in asset system' >> $LOGFILE");
   print $html->p("Setting status of $host to $status in asset system");

#   print LOGFL "curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'POSTVAR=$assetrec' -v http://ipsms/XmlPostHandler/autodeploy.post >> /var/log/decomasset.log\n";
#    my $req = POST "$url", [HOST_NAME=>"$host_name",TASK=>"$action"];
      my $url = "http://sdebldr/SDEWebServices/set_asset_status.asmx/Execute";

    my $res = $ua->request(POST "$url", [ host => "$host", status => "$status" ]);
#   system("echo 'curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'POSTVAR=$assetrec' -v http://ipsms/XmlPostHandler/autodeploy.post' >> $LOGFILE");
#   system("curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'POSTVAR=$assetrec' -v http://ipsms/XmlPostHandler/autodeploy.post >> /var/log/decomasset.log");
} #close decom_asset sub
###################################################################################################################################################
sub update_ipweb {
   my $host_name =  $html->param('host_name');
   my $ip_addr = $html->param('ip_addr');
   my $management_ip = $html->param('management_ip'); # ILO
   my @pads;

   if ( !$ip_addr ) { print $html->h2("No IP Address, please add one in Asset System\n"); exit; }

  # for ipweb
#print $html->p("Diag: Connection ");
 my $dbh_ipw = DBI->connect("DBI:Pg:database=$db_name_ipw;host=$db_host_ipw;port='$pg_port'", "$db_user_ipw",
          "$db_pass_ipw", {PrintError => 1, RaiseError => 0, AutoCommit => 1});
my $err_msg = $DBI::errstr;
#print $html->p("Diag: Connection $err_msg");
   #  ip and pad with 0 to make 3 char
   my @ips = split(/\./,$ip_addr);
   for ( my $i=0;$i < scalar(@ips);$i++ ) {
      if (length($ips[$i]) lt '2') { @pads[$i] = "00".$ips[$i]; }
      elsif (length($ips[$i]) lt '3') { @pads[$i] = "0".$ips[$i]; }
      else { @pads[$i] = $ips[$i]; }
   } # end for

   my $padded_ip = "$pads[0].$pads[1].$pads[2].$pads[3]";
   my $subnet = "$pads[0].$pads[1].$pads[2].000";

   #Changed to a simple record delete KLS 10/15/15
   #my $up1 = "update ip_list set monitor = 'No', icmp = '0', snmp = '0', responsible_person = 'decommissioned' where ip_address = '$padded_ip' \n";
   my $up1 = "delete from ip_list where ip_address = '$padded_ip' \n";

    $dbh_ipw->do($up1);
    print $html->p("Updating IP Web for host: $host_name IP: $ip_addr");
    system("echo 'Updating IP Web for host: $host_name IP: $ip_addr' >> $LOGFILE");
    #print $html->p("SQL: $up1\n");

   # split ip and pad with 0 to make 3 char for management port (ILO)
   my @ips = split(/\./,$management_ip);
   for ( my $i=0;$i < scalar(@ips);$i++ ) {
      if (length($ips[$i]) lt '2') { @pads[$i] = "00".$ips[$i]; }
      elsif (length($ips[$i]) lt '3') { @pads[$i] = "0".$ips[$i]; }
      else { @pads[$i] = $ips[$i]; }
   } # end for

   my $padded_management_ip = "$pads[0].$pads[1].$pads[2].$pads[3]";
   my $management_subnet = "$pads[0].$pads[1].$pads[2].000";
   if ( $management_ip ) {
      #Changed to a simple record delete KLS 10/15/15
      #my $up2 = "update ip_list set responsible_person = 'decommissioned' where ip_address = '$padded_management_ip' \n";
       my $up2 = "delete from ip_list where ip_address = '$padded_management_ip' \n";

       $dbh_ipw->do($up2);
       print $html->p("Updating IP Web for ILO host: $host_name IP: $management_ip");
       system("echo 'Updating IP Web for ILO host: $host_name IP: $management_ip' >> $LOGFILE");
       #print $html->p("SQL: $up2\n");
    } #end if

 $dbh_ipw->disconnect();
} #end update ipweb
###################################################################################################################################################
sub wysdm_update
        {
        my $host_name =  $html->param('host_name');
        my $partner_id = $html->param('partner_id');
        my $OS = $html->param('OS');

        if ($testing==1)
                {
                print "Old Values:<br>\$host_name = $host_name<br>\$partner_id = $partner_id<br>\$OS = $OS<br><br>";
                print 'Using Test Parameters<br>';
                $host_name = 'testks03-ius-01-001-nbma';
                }

        my $url = "http://wysdmbldr:3231/cgi-bin/wysaddnode.cgi";

        print $html->p("Generating Wysdm Commission request for Host: $host_name");

        my $req = POST "$url", [HOSTNAME=>"$host_name",PLATFORM=>"$OS",PARTNER=>"$partner_id"];
        my $res = $ua->request($req);

        if ($testing == 1)
                {
                print "<h2>Results of URL call of $url:<br> ";

                if ($res->is_success) {
                        print "Passed: " . $res->decoded_content;
                    }
                    else {
                        print "Error: " . $res->status_line;
                    }

                print "</h2>";
                }

#       my $command = "/var/www/sites/deploy/scripts/updwysdm.pl add $host_name $partner_id $OS ";
#
#       print "\$command = $command<br>" if $testing==1;

        ######################################################################################
        # Between there remarks was starred out
#       system("echo '$command' >> $LOGFILE");
#       print $html->h1("command: $command\n");
#       my $outCode = system("$command");
#
#       print "\$outCode = $outCode<br>" if $testing==1;
#
#       $outCode = $outCode >> 8;
#       if ( $outCode eq '90' )
#               {
#               print $html->p("Skipping Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
#               system("echo 'Skipping Wysdm for Host: $host_name Partner: $partner_id OS: $OS' >> $LOGFILE");
#               } # end if
#       elsif ( $outCode eq '100' )
#               {
#               print $html->p("Invalid charactor in name: $host_name Partner: $partner_id OS: $OS");
#               system("echo 'Invalid charactor in name: $host_name Partner: $partner_id OS: $OS' >> $LOGFILE");
#               return 1;
#               } # end elsif
#       elsif ( !$outCode )
#               {
#               print $html->p("Updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
#               system("echo 'Updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS' >> $LOGFILE");
#               return 0;
#               }
#       else
#               {
#               print $html->p("Unknown error updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
#               system("echo 'Unknown error updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS' >> $LOGFILE");
#               return 1;
#               } # end else
#       print $html->p("Updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
        } # end wysdm update sub
        # End os un-remarked code
        ##########################################################################################
###################################################################################################################################################
sub wysdm_decomp {
   my $host_name =  $html->param('host_name');
   my $partner_id = $html->param('partner_id');
   my $OS = $html->param('OS');

   my $url = "http://wysdmbldr:3231/cgi-bin/wysdelnode.cgi";

   print $html->p("Generating Wysdm Decom request for Host: $host");

    my $req = POST "$url", [HOSTNAME=>"$host_name",PLATFORM=>"$OS"];
    my $res = $ua->request($req);
   my $command = "/var/www/sites/deploy/scripts/updwysdm.pl decom $host_name $partner_id $OS ";
#   print $html->h1("command: $command\n");
   my $outCode = system("$command");
   $outCode = $outCode >> 8;
   if ( $outCode eq '90' ) {
      print $html->p("Skipping Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
      return 1;
   } # end if
   elsif ( $outCode eq '100' ) {
      print $html->p("Invalid charactor in name: $host_name Partner: $partner_id OS: $OS");
      return 1;
   } # end elsif
   elsif ( !$outCode ) {
      print $html->p("Updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
      return 0;
   }
   else {
      print $html->p("Unknown error updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
      return 1;
   } # end else
   #print $html->p("Updating Wysdm for Host: $host_name Partner: $partner_id OS: $OS");
} # end wysdm decomp sub
###################################################################################################################################################
sub check_ipweb {
   my $host_name =  $html->param('host_name');
   my $ip_addr = $html->param('ip_addr');
   my $type = $html->param('type');
   my $description = $html->param('description');
   my $pid = $html->param('pid');
   my $partner_id = $html->param('partner_id');
   my $OS = $html->param('OS');
   my $product = $html->param('product'); # Viaback, etc.
   my $management_ip = $html->param('management_ip'); # ILO
   my $subnet_lst = $html->param('subnet_lst');
   my @pads;
   my $ipwebdevice_type;
   my $subnet;

   if ( !$OS ) { print $html->h1("<font color='red'>You must select an OS to use. </font>"); exit; }
   if ( !$ip_addr ) { print $html->h2("No IP Address, please add one in Asset System\n"); exit; }

  # for ipweb
 my $dbh_ipw = DBI->connect("DBI:Pg:database=$db_name_ipw;host=$db_host_ipw;port='$pg_port'", "$db_user_ipw",
          "$db_pass_ipw", {PrintError => 1, RaiseError => 0, AutoCommit => 1}) || die "Unable to connect to IP Web database";

   # split ip and pad with 0 to make 3 char
   my @ips = split(/\./,$ip_addr);
   for ( my $i=0;$i < scalar(@ips);$i++ ) {
      if (length($ips[$i]) lt '2') { @pads[$i] = "00".$ips[$i]; }
      elsif (length($ips[$i]) lt '3') { @pads[$i] = "0".$ips[$i]; }
      else { @pads[$i] = $ips[$i]; }
   } # end for

   my $padded_ip = "$pads[0].$pads[1].$pads[2].$pads[3]";
   if ( !$subnet_lst ) {
      $subnet = "$pads[0].$pads[1].$pads[2].000";
   } # end if
   else {
      $subnet = $subnet_lst;
   } # end else

   # split ip and pad with 0 to make 3 char for management port (ILO)
   my @ips = split(/\./,$management_ip);
   for ( my $i=0;$i < scalar(@ips);$i++ ) {
      if (length($ips[$i]) lt '2') { @pads[$i] = "00".$ips[$i]; }
      elsif (length($ips[$i]) lt '3') { @pads[$i] = "0".$ips[$i]; }
      else { @pads[$i] = $ips[$i]; }
   } # end for

   my $padded_management_ip = "$pads[0].$pads[1].$pads[2].$pads[3]";
   my $management_subnet = "$pads[0].$pads[1].$pads[2].000";

   #print $html->h3("IP: $padded_ip  Subnet: $subnet ");
    # check for ip addr and exit if exists
    my $q1="select count(*) from ip_list where ip_address = '$padded_ip'";
#    print $html->h1("SQL: $q1");
     my $sth_ipw = $dbh_ipw->prepare($q1);
      $sth_ipw->execute();
      my ($check_ip) = $sth_ipw->fetchrow_array();
       if ( $check_ip ) { print $html->h2("IP $ip_addr already in IP Web Page database\n"); exit; }
       $sth_ipw->finish();
    # check for subnet and exit if does not exist
    my $q1="select count(*) from ip_subnets where subnet_address = '$subnet'";
#    print $html->h1("SQL: $q1");
     my $sth_ipw = $dbh_ipw->prepare($q1);
      $sth_ipw->execute();
      my ($check_subnet) = $sth_ipw->fetchrow_array();
     # see if there is a list of subnets if a /24 match is not found
       if ( !$check_subnet ) {
   #       print $html->h2("$subnet subnet for IP $ip_addr not found in IP Web Page database\n");
          print $html->h2("No subnets found in the IP web page that match /24 network $subnet ... Checking using IDC\n");
            my @idcs = split(/-/,$host_name);
            my $idc = @idcs[0];
#            print $html->h2("IDC: $idc\n");
            my $q="select subnet_address from ip_subnets where idc = '$idc'\n";
              my $sth_sub = $dbh_ipw->prepare($q);
#              print $html->h2("SQL: $q\n");
              $sth_sub->execute();
               if ( !($sth_sub->rows()) ) {
                 print $html->h2("No subnets found in the IP web page that match IDC $idc, either. Exiting\n");
                  exit; # exit if no other subnets found.
               } # end if
               print $html->start_form(-name=>"deploymentautomation",-action=>"$prog_name",-method=>"POST");
                print $html->p("Please select a subnet from the list\n");
                 print $html->hidden(-name=>'host_name',-value=>"$host_name"),$html->hidden(-name=>'ip_addr',-value=>"$ip_addr");
                 print $html->hidden(-name=>'type',-value=>"$type"),$html->hidden(-name=>'description',-value=>"$description");
                 print $html->hidden(-name=>'pid',-value=>"$pid"),$html->hidden(-name=>'partner_id',-value=>"$partner_id");
                 print $html->hidden(-name=>'product',-value=>"$product"),$html->hidden(-name=>'management_ip',-value=>"$management_ip");
                 print $html->hidden(-name=>'OS',-value=>"$OS");
                # 12/11/12 KLS Added sid variable. If not there, this part would take you back to login.
                print "<input type=\"hidden\" name=\"sid\" value=\"$sid\">\n";
                #EOM
                  if ( $subnet_lst eq '2' ) { print $html->p("You must select a subnet from the list\n"); }
                print "<table border=0><tr><td>\n";
                 print "<select name='subnet_lst' class='button'>\n";
                  print "<option value='2'>Select Subnet\n";
                 while ( my($subnet) = $sth_sub->fetchrow_array() ) {
                   print "<option value='$subnet'>$subnet\n";
                 } # end while
                 print "</select>\n";
              $sth_sub->finish();
              print "<tr><td>\n";
              print $html->submit(-class=>'button',-name=>'Deploy',-value=>'Deploy');
              print "</table>\n";
             print $html->end_form();
          exit;
       }

      if ( ($OS eq 'Windows') && ($product eq 'ViaBack' ) ) {
         $ipwebdevice_type = "Windows NBU Master";
      } # end if
      elsif ( $host_name =~ /NBMA/ ) { $ipwebdevice_type = "NBU Master server"; }
      elsif ( $host_name =~ /NBME/ ) { $ipwebdevice_type = "NBU Media Server"; }
      elsif ( $host_name =~ /AXMS/ ) { $ipwebdevice_type = "Axion Utility node"; }
      elsif ( $host_name =~ /AXSS/ ) { $ipwebdevice_type = "Axion Mini-S"; }
      elsif ( $host_name =~ /AXSD/ ) { $ipwebdevice_type = "Axion Data Node"; }
      elsif ( $host_name =~ /FPO/ ) { $ipwebdevice_type = "FPO Server"; }
      elsif ( $host_name =~ /SRE/ ) { $ipwebdevice_type = "Windows SRE Server"; }
      elsif ( $type =~ /Data Domain/ ) { $ipwebdevice_type = "Data domain"; }
      elsif ( $OS eq 'Solaris' ) { $ipwebdevice_type = "Solaris Server"; }
      elsif ( $OS eq 'Linux' ) { $ipwebdevice_type = "Linux Server"; }
      elsif ( $OS eq 'Windows' ) { $ipwebdevice_type = "Windows Server"; }
      elsif ( $OS eq 'AIX' ) { $ipwebdevice_type = "AIX Server"; }
      else {
          my $q1="select count(*) from ip_lov_devtype where device_type = '$description' ";
#           print $html->h1("SQL: $q1");
           my $sth_ipw = $dbh_ipw->prepare($q1);
             $sth_ipw->execute();
             my ($dev_count) = $sth_ipw->fetchrow_array();
             $sth_ipw->finish();
           if ( $dev_count ) { $ipwebdevice_type = "$description"; }
           else {
              my $ins = "insert into ip_lov_devtype (  device_type ) values ('$description') \n";
#              print $html->h1("SQL: $ins");
               $dbh_ipw->do($ins);
              $ipwebdevice_type = "$description";
           } # end else
      } # end main else

      my $ins = "INSERT INTO ip_list (subnet_address, ip_address, machine_name, machine_desc, monitor, device_type, icmp, snmp) values \n";
      $ins=$ins."( '$subnet', '$padded_ip', '$host_name', '$description', 'Yes', '$ipwebdevice_type', '1', '1') \n";
#      print $html->h1("SQL: $ins");
       $dbh_ipw->do($ins);
       print $html->p("Updating IP Web for host: $host_name IP: $ip_addr");

     if ( $management_ip ) {
        my $ins = "INSERT INTO ip_list (subnet_address, ip_address, machine_name, machine_desc, monitor, device_type, icmp, snmp) values \n";
        $ins=$ins."( '$management_subnet', '$padded_management_ip', '$host_name', '$description', 'No', 'ILO Port', '0', '0') \n";
         #print $html->h1("SQL: $ins");
       $dbh_ipw->do($ins);
       print $html->p("Updating IP Web for ILO host: $host_name IP: $management_ip")
     } # end if

   $dbh_ipw->disconnect();

} # end check ip web
###################################################################################################################################################
sub viaremote_update {
   my $host_name =  $html->param('host_name');
   my $ip_addr = $html->param('ip_addr');
   my $type = $html->param('type');
   my $description = $html->param('description');
   my $pid = $html->param('pid');
   my $partner_id = $html->param('partner_id');

    # skip if viaremote cap not needed
   if ( (uc($host_name) =~ /AXSS/) || (uc($host_name) =~ /AXMS/) ) { print $html->p("Updating ViaRemoteCap for host: $host_name"); } # continue if Viaremotecap needs updating
   else { print $html->p("Skipping update of ViaRemoteCap for host: $host_name"); return 0; }

   print $html->p("Viaremotecap updated: $host_name, $ip_addr, $type, $description, $pid, $partner_id");
   my $ins = "insert into sites (sitename,active,version,description,pid) \n";
   $ins=$ins."values ('$host_name','1','3','$description','$partner_id') \n";
#print $html->h1("SQL: $ins <br>\n");
    my $sth = $dbh->prepare($ins);
     $sth->execute();
     $sth->finish();
   return 0;
} # end via remote update sub
###################################################################################################################################################
sub update_dns
        {
        print "========================= DNS SETUP =========================\n";
        my $host =  uc($html->param('host_name'));
        my $ip = $html->param('ip_addr');
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
        #   my $url = "http://it-home/dns/dnsaddreq.cgi";
        my $cmd = "/usr/local/bin/update-ddns.sh";

        print $html->p("Updating DNS for Host: $host IP: $ip ");

        my $f_fqdn = $host . ".bcrs-vaults.ibm.com";
        my($o1, $o2, $o3, $o4) = split(/\./, $ip, 4);
        my $r_fqdn = $o4 . "." . $o3 . "." . $o2 . "." . $o1 . ".in-addr.arpa";

        #    my $req = POST "$url", [IP=>"$ip_addr",HOSTNAME=>"$host_name",SubmitButton=>'ADD'];
        #    my $res = $ua->request($req);

        # KLS Added pre-comment of  addzone.sh 5/20/13
        my $add_cmd = "/usr/local/bin/addzone.sh";
        my $pre_fqdn = $o3 . "." . $o2 . "." . $o1 . ".in-addr.arpa";
        my $pre_res = `$add_cmd $pre_fqdn`;
        # EOM

        print "DNS Command: $cmd -a $f_fqdn $ip $r_fqdn \n";
        my $res = `$cmd -a $f_fqdn $ip $r_fqdn`;
        # return 0;
        # KLS 5/7/15 Added to try twice and test

        # sleep for 5 secs then rerun it
        sleep 5;
        my $res2 = `$cmd -a $f_fqdn $ip $r_fqdn`;

        #need to add below to test and see if the dns update was successful
        my $forward_result = `nslookup $host | grep $ip`;
        my $reverse_result = `nslookup $ip | grep -i $f_fqdn`;

        my $dns_rtn = 0;
        if(length($reverse_result) == 0 or length($forward_result) == 0)
                {
                $dns_rtn = 1;
                print "\nNot set up properly: <br>" .
                "Forward Result:".
                "$forward_result<br><br>" .
                "Reverse Result:" .
                "$reverse_result<br>";
                # #      #if its zero then dns didnt work
                my $msg = "Error occurred checking DNS for $host at $ip";
                my $ok = send_comm_email("DNS Configuration Issue - $host", $msg, $dns_distro); #send_email then mail.
                }
        else
                {
                print "DNS testing was successful<br>";
                }

        my $ilo_param = $html->param('Make_ILO');
        print "Make_ILO paramater = " . $ilo_param . "<br>" ;

        if ($ilo_param eq 'Make_ILO')
                {
                # This ought to look familiar - it was pinched from the code directly above this.
                print "========================= ILO DNS SETUP =========================\n";
                my $host =  uc($html->param('host_name')) . "-ILO";
                my $ip = $html->param('management_ip');

                print "<hr>Creating DNS record for ILO Host $host at IP $ip<br>";

                my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
                my $cmd = "/usr/local/bin/update-ddns.sh";

                print $html->p("Updating DNS for Host: $host IP: $ip ");

                my $f_fqdn = $host . ".bcrs-vaults.ibm.com";
                my($o1, $o2, $o3, $o4) = split(/\./, $ip, 4);
                my $r_fqdn = $o4 . "." . $o3 . "." . $o2 . "." . $o1 . ".in-addr.arpa";

                my $add_cmd = "/usr/local/bin/addzone.sh";
                my $pre_fqdn = $o3 . "." . $o2 . "." . $o1 . ".in-addr.arpa";
                my $pre_res = `$add_cmd $pre_fqdn`;

                print "ILO DNS Command: $cmd -a $f_fqdn $ip $r_fqdn \n";

                my $res = `$cmd -a $f_fqdn $ip $r_fqdn`;
                sleep 5;
                my $res2 = `$cmd -a $f_fqdn $ip $r_fqdn`;

                my $forward_result = `nslookup $host | grep $ip`;
                my $reverse_result = `nslookup $ip | grep -i $f_fqdn`;

                my $dns_rtn = 0;
                if(length($reverse_result) == 0 or length($forward_result) == 0)
                        {
                        $dns_rtn = 1;
                        print "\nNot set up properly: <br>" .
                        "Forward Result:".
                        "$forward_result<br><br>" .
                        "Reverse Result:" .
                        "$reverse_result<br>";
                        my $msg = "Error occurred checking DNS for $host at $ip";
                        my $ok = send_comm_email("DNS Configuration Issue - $host", $msg, $dns_distro); #send_email then mail.
                        }
                else
                        {
                        print "ILO DNS testing was successful<br>";
                        }
                }

        return $dns_rtn;
        # EOM
        } # end update dns sub
###################################################################################################################################################
sub decomp_dns {
print "========================= DECOMM DNS =========================\n";
my $host =  $html->param('host_name');
   my $ip = $html->param('ip_addr');

   my $cmd = "/usr/local/bin/update-ddns.sh";

   print $html->p("Updating DNS for Host: $host IP: $ip ");

   my $f_fqdn = $host . ".bcrs-vaults.ibm.com";
   my($o1, $o2, $o3, $o4) = split(/\./, $ip, 4);
   my $r_fqdn = $o4 . "." . $o3 . "." . $o2 . "." . $o1 . ".in-addr.arpa";

   my $res = `$cmd -d $f_fqdn $ip $r_fqdn`;
   return 0;

} # end decomp dns sub
###################################################################################################################################################
sub viaremote_decomp {
   my $host_name =  $html->param('host_name');
   my $ip_addr = $html->param('ip_addr');
   my $type = $html->param('type');
   my $description = $html->param('description');
   my $pid = $html->param('pid');
   my $partner_id = $html->param('partner_id');

    # skip if viaremote cap not needed
   if ( (uc($host_name) =~ /AXSS/) || (uc($host_name) =~ /AXMS/) ) { print $html->p("Updating ViaRemoteCap for host: $host_name"); } # continue if Viaremotecap needs updating
   else { print $html->p("Skipping decommission of ViaRemoteCap for host: $host_name"); return; }

   print $html->p("Viaremotecap decommissioned: $host_name, $ip_addr, $type, $description, $pid, $partner_id");
   my $ins = "insert into sites (sitename,active,version,description,pid) \n";
   $ins=$ins."values ('$host_name','1','3','$description','$partner_id') \n";
   my $up1="update sites set active='0' where sitename = '$host_name'";
     $dbh->do($up1);
#print $html->p("PID: $pid");
   return 0;
} # end via remote update sub
###################################################################################################################################################
sub send_email {
   my ( $subject, $message ) = @_;
   my $sendmail = '/usr/sbin/sendmail';
   my $to = "timpar\@us.ibm.com";

      open( MAIL, "|$sendmail -t" );
      #binmode(MAIL, ":encoding(utf8)");
    print MAIL "To: $to \n";
    print MAIL "Subject: $subject $message\n";
    print MAIL "From: DeploymentAutomation\n";
    print MAIL "$message \n\n";
   close( MAIL );
} # end send email sub
###################################################################################################################################################
sub send_failure_notice {
   my $dl = "timpar\@us.ibm.com";

   my $mail = "/bin/mail";
   my $subj = "Failure in Auto-deploy process";

   my $note = "There was a failure in the auto-deploy or decomission process. Please see the log file for more information.";

   my $mailcmd = "$mail -s '$subj' $dl < $note";
   `$mailcmd`;

}
###################################################################################################################################################
# 6/28/13 add email to various people for commission/decommissions

sub send_comm_email {
        my ( $subject, $message, $distro ) = @_;

        print "Email being sent:<br>",
                "To: $distro<br>",
                "Subject: $subject<br>",
                "Message: $message<br>";

        my $sendmail = '/usr/sbin/sendmail';
        my $to = "$distro";
        open( MAIL, "|$sendmail -t" );
                #binmode(MAIL, ":encoding(utf8)");
        print MAIL "To: $to \n";
        print MAIL "From: DeploymentAutomation\n";
        print MAIL "Subject: $subject\n";
        print MAIL "$message\n";
        close( MAIL );
   }

###################################################################################################################################################
# 4/5/12 KLS Added deploy_st - deploy to create records in the Site Transition database
sub deploy_st
        {
        my $rtnval = 0;
        my $rows = 0;
        $host_st =  DBI->connect("DBI:Pg:database=$db_name_st;host=$db_host_st;port='$pg_port'", "$db_user_st","$db_pass_st", {PrintError => 1, RaiseError => 0, AutoCommit => 1});
        my $new_site_id = $html->param('host_name');

        my $st_site_check_sql = "select site_id from $db_schema_st.site where site_id = '$new_site_id'";

        my $sth = $host_st->prepare($st_site_check_sql);
        $sth->execute();

        my $st_site_check_record = $sth->fetchrow_hashref();
        if ($st_site_check_record->{'site_id'} eq $new_site_id)
                {
                print $html->p("Site $new_site_id already exists in the Site Transition System");
                system("echo 'Site $new_site_id already exists in the Site Transition System' >> $LOGFILE");
                }
        else
                {
                my $st_sql = "insert into $db_schema_st.site (site_id, site_status, transition) values ('$new_site_id', '3c', 'Site Created')";

                $rows = $host_st->do($st_sql);
                print "Site Update: \$rows = $rows<br>";

                if ($rows == 0)
                        {
                        print $html->p("Creation of Site Transition Record for $new_site_id failed");
                        system("echo 'Creation of Site Transition Record for $new_site_id failed' >> $LOGFILE");
                        $rtnval = 1;
                        }
                else
                        {
                        print $html->p("Creation of Site Transition Record for $new_site_id successful");
                        system("echo 'Creation of Site Transition Record for $new_site_id successful' >> $LOGFILE");

                        my $time_stamp = make_time_stamp();

                        my $st_hist_sql = "insert into $db_schema_st.history " .
                                "(site_id, " .
                                "username, " .
                                "status, " .
                                "comments, " .
                                "role, " .
                                "timestamp) " .
                                "VALUES " .
                                "('$new_site_id', " .
                                "'auto_deploy', " .
                                "'Site Created', " .
                                "'Site Created by the Auto-Deploy Script', " .
                                "'auto-deploy', " .
                                "'$time_stamp')" ;

                        print "\$st_hist_sql = $st_hist_sql<br>";

                        $rows = $host_st->do($st_hist_sql);
                        print "History Update: \$rows = $rows<br>";
                        if ($rows == 0)
                                {
                                $rtnval = 1;

                                print $html->p("Creation of Site Transition History Record for $new_site_id failed");
                                system("echo 'Creation of Site Transition History Record for $new_site_id failed' >> $LOGFILE");
                                }
                        else
                                {
                                print $html->p("Creation of Site Transition History Record for $new_site_id successful");
                                system("echo 'Creation of Site Transition History Record for $new_site_id successful' >> $LOGFILE");
                                }

                        }
                }

        if ($update_cep == 1)
                {
                my $cep_sql = "select host_name from  $db_schema_st.cep where host_name = '$new_site_id'";
                print "cep_sql1 = $cep_sql<br>";
                my $cep_result = $host_st->prepare($cep_sql);
                $cep_result->execute();
                my $cep_record = $cep_result->fetchrow_hashref();
                if ($cep_record->{'host_name'} ne "")
                        {
                        $rtnval =  1;
                        print $html->p("CEP Record for $new_site_id already exists");
                        system("echo 'CEP Record for $new_site_id already exists' >> $LOGFILE");
                        }
                else
                        {
                        my $cep_sql = "insert into $db_schema_st.cep (host_name) values ('$new_site_id')";
                        print "cep_sql2 = $cep_sql<br>";

                        $rows = $host_st->do($cep_sql);

                        if ($rows == 0)
                                {
                                $rtnval = 1;

                                print $html->p("Creation of CEP Record for $new_site_id failed");
                                system("echo 'Creation of CEP Record for $new_site_id failed' >> $LOGFILE");
                                }
                        else
                                {
                                print $html->p("Creation of CEP Record for $new_site_id successful");
                                system("echo 'Creation of CEP Record for $new_site_id successful' >> $LOGFILE");
                                }
                        }
                }
        else
                {
                print $html->p("Creation of CEP Record for $new_site_id skipped");
                system("echo 'Creation of CEP Record for $new_site_id skipped' >> $LOGFILE");
                }

        ## KLS 4/20/15 This part will add in the site attributes that are to be checked.
        if (0) {
        my $att_list_sql = "SELECT * FROM $db_schema_st.site_attrib_type order by device_type";
        my $att_list_result = $host_st->prepare($att_list_sql);
        $att_list_result->execute();

        print $html->start_form(-name=>"deploymentautomation",-action=>"$prog_name",-method=>"POST");
        print "<table align=\"center\" border=\"5\" bgcolor=\"silver\">\n";
        my $max_id = 0;

        while (my $att_list_record = $att_list_result->fetchrow_hashref())
                {
        $max_id = $att_list_record->{'id'} if $att_list_record->{'id'} > $max_id;

                my $check_field = 'group' . $att_list_record->{'id'} . '_input';

                print "<tr>\n" ,
                        "<td>$att_list_record->{'platform'}</td>\n",
                        "<td>$att_list_record->{'device_type'}</td>\n",
                        "<td>$att_list_record->{'description'}</td>\n",
                        "<td><input name=\"$check_field\" type=\"checkbox\"><br></td></tr>\n";

                }
        print "<tr><td colspan=\"4\" align=\"center\">" .
                "<input type=\"hidden\" name = \"sid\" value = \"$sid\">" .
                "<input type=\"hidden\" name = \"max_id\" value = \"$max_id\">" .
                "<input type=\"hidden\" name = \"new_site_id\" value = \"$new_site_id\">".
                "<input name=\"Submit_attrib_list\" value=\"Submit\" type=\"submit\"></td></tr>\n</table>\n";

        print $html->end_form();
        }
        ## EOM
        #
        $host_st->disconnect();
        return $rtnval;
        }
###################################################################################################################################################
sub decomm_st
        {
        print "In the site decommission section.<br>" if $testing==1;

        # Since the decomm site is only in the testing phases, use the real sites
        my $rtnval = 0;
        $host_st =  DBI->connect("DBI:Pg:database=$db_name_st;host=$db_host_st;port='$pg_port'", "$db_user_st","$db_pass_st", {PrintError => 1, RaiseError => 0, AutoCommit => 1});
        my $new_site_id = $html->param('host_name');

        my $st_site_check_sql = "select site_id from $db_schema_st.decomm_site where site_id = '$new_site_id'";
        print "\$st_site_check_sql = $st_site_check_sql<br>" if $testing==1;

        my $sth = $host_st->prepare($st_site_check_sql);
        $sth->execute();

        my $st_site_check_record = $sth->fetchrow_hashref();
        if ($st_site_check_record->{'site_id'} eq $new_site_id)
                {
                print $html->p("Site $new_site_id already exists in the Site Decommission System");
                system("echo 'Site $new_site_id already exists in the Site Decommission System' >> $LOGFILE");
                }
        else
                {
                my $st_sql = "insert into $db_schema_st.decomm_site (site_id, transition) values ('$new_site_id', 'Site Created')";
                print "Ready to create decomm record - <br>\$st_sql = $st_sql<br>" if $testing==1;

                my $rows;
                $rows = $host_st->do($st_sql);
                print "Site Update: \$rows = $rows<br>" if $testing==1;

                if ($rows == 0)
                        {
                        print $html->p("Creation of Site Decommission Record for $new_site_id failed");
                        system("echo 'Creation of Site Decommission Record for $new_site_id failed' >> $LOGFILE");
                        $rtnval = 1;
                        }
                else
                        {
                        print $html->p("Creation of Site Decommission Record for $new_site_id successful");
                        system("echo 'Creation of Site Decommission Record for $new_site_id successful' >> $LOGFILE");

                        my $time_stamp = make_time_stamp();

                        my $st_hist_sql = "insert into $db_schema_st.decomm_history " .
                                "(site_id, " .
                                "username, " .
                                "comments, " .
                                "status, " .
                                "role, " .
                                "timestamp) " .
                                "VALUES " .
                                "('$new_site_id', " .
                                "'auto_deploy', " .
                                "'Decommission record created', " .
                                "'Decommission record created', " .
                                "'', ".
                                "'$time_stamp')" ;

                        print "\$st_hist_sql = $st_hist_sql<br>" if $testing==1;

                        $rows = $host_st->do($st_hist_sql);
                        print "History Update: \$rows = $rows<br>" if $testing==1;
                        if ($rows == 0)
                                {
                                $rtnval = 1;

                                print $html->p("Creation of Site Decommission History Record for $new_site_id failed");
                                system("echo 'Creation of Site Deommission History Record for $new_site_id failed' >> $LOGFILE");
                                }
                        else
                                {
                                print $html->p("Creation of Site Decommission History Record for $new_site_id successful");
                                system("echo 'Creation of Site Decommission History Record for $new_site_id successful' >> $LOGFILE");
                                }
                        }
                }
        #-------------------------------------------------------------------------------------------------------------------------------
        print "In the site transition section.<br>" if $testing==1;

        # Since the decomm site is only in the testing phases, use the real sites
        my $rtnval = 0;
        $host_st =  DBI->connect("DBI:Pg:database=$db_name_st;host=$db_host_st;port='$pg_port'", "$db_user_st","$db_pass_st", {PrintError => 1, RaiseError => 0, AutoCommit => 1});
        my $new_site_id = $html->param('host_name');

        my $st_site_check_sql = "select site_id from $db_schema_st.site where site_id = '$new_site_id'";
        print "\$st_site_check_sql = $st_site_check_sql<br>" if $testing==1;

        my $sth = $host_st->prepare($st_site_check_sql);
        $sth->execute();

        my $st_site_check_record = $sth->fetchrow_hashref();
        if ($st_site_check_record->{'site_id'} ne $new_site_id)
                {
                print $html->p("Site $new_site_id does not exist in the Site Transition System");
                system("echo 'Site $new_site_id does not exist in the Site Transition System' >> $LOGFILE");
                }
        else
                {
                #my $st_sql = "insert into $db_schema_st.decomm_site (site_id, transition) values ('$new_site_id', 'Site Created')";
                my $st_sql = "update $db_schema_st.site " .
                            "set transition = 'Site Decommed in Auto-Deploy by $uid', " .
                            "site_status = 'DD' " .
                            "where site.site_id = '$new_site_id'";

                print "Ready to mark site transition record as decommed - <br>\$st_sql = $st_sql<br>" if $testing==1;

                my $rows;
                $rows = $host_st->do($st_sql);
                print "Site Update: \$rows = $rows<br>" if $testing==1;

                if ($rows == 0)
                        {
                        print $html->p("Update of Site Transition Record for $new_site_id failed");
                        system("echo 'Update of Site Transition Record for $new_site_id failed' >> $LOGFILE");
                        $rtnval = 1;
                        }
                else
                        {
                        print $html->p("Update of Site Transition Record for $new_site_id successful");
                        system("echo 'Update of Site Transition Record for $new_site_id successful' >> $LOGFILE");

                        my $time_stamp = make_time_stamp();

                        my $st_hist_sql = "insert into $db_schema_st.history " .
                                "(site_id, " .
                                "username, " .
                                "comments, " .
                                "status, " .
                                "role, " .
                                "timestamp) " .
                                "VALUES " .
                                "('$new_site_id', " .
                                "'$uid', " .
                                "'Decommissed from auto-deploy', " .
                                "'Decommissed from auto-deploy', " .
                                "'', ".
                                "'$time_stamp')" ;

                        print "\$st_hist_sql = $st_hist_sql<br>" if $testing==1;

                        $rows = $host_st->do($st_hist_sql);
                        print "History Update: \$rows = $rows<br>" if $testing==1;
                        if ($rows == 0)
                                {
                                $rtnval = 1;

                                print $html->p("Creation of Site Transition History Record for $new_site_id failed");
                                system("echo 'Creation of Site Transition History Record for $new_site_id failed' >> $LOGFILE");
                                }
                        else
                                {
                                print $html->p("Creation of Site Transition History Record for $new_site_id successful");
                                system("echo 'Creation of Site Transition History Record for $new_site_id successful' >> $LOGFILE");
                                }
                        }
                }


        $host_st->disconnect();
        return $rtnval;


        }
###################################################################################################################################################
sub make_time_stamp
        {
        # create the date_time field for the history file so it looks juuuuust like the original.
        my ($sec,$min,$hour,$day,$month,$yr19,@rest) =   localtime(time); ####### To get the localtime of your system

        my $outyear = sprintf("%04d",$yr19+1900); ## Since year returns the # of years since 1900 have to add 1900 to the result.
        $month++; ## Month is zero based - 0 = January, 1 = February, etc.
        my $outmonth = sprintf("%02d",$month);

        my $dt_date = $outyear . '-' . $outmonth . '-' . sprintf("%02d",$day);
        my $dt_time = sprintf("%02d",$hour).":".sprintf("%02d",$min).":".sprintf("%02d",$sec);

        my $timestamp = "$dt_date $dt_time";

        return $timestamp;
        }

sub is_valid_ip
        {
        my $in_ip = shift;
        chomp($in_ip);
        #print "in ip = '$in_ip'\n";
        $in_ip =~ s/\./,/g;
        #print "Commas: $in_ip\n";
        my @ip_parts = split(",",$in_ip);
        my $rtnval = 1;

        my $arraysize = scalar (@ip_parts);
        #print "Array size: $arraysize\n";
        for (my $x=0; $x<= 3; $x++)
                {
                #print "Part $x = $ip_parts[$x]: ";
                if ($ip_parts[$x] < 0 or $ip_parts[$x] > 255 or !($ip_parts[$x] =~ /^[+-]?\d+$/ ))
                        {
                        $rtnval = 0;
                        }
                #print "$rtnval\n";
                }
        #print $arraysize . " pieces\n";
        if ($arraysize > 4)
                {
                $rtnval = 0;
                }

        if ($ip_parts[0] == $ip_parts[1] and $ip_parts[1] == $ip_parts[2] and $ip_parts[2] == $ip_parts[3])
                {
                $rtnval = 0;
                }

        #print "Return value: $rtnval\n\n";
        return $rtnval;
        }

#############################################################3
sub create_site_attribs
        {
        #print "In Create_Site_Attribs<br>";
        my $param_list = shift;
        my $site_id = shift;

        #print "Last character = " . substr($param_list,-1) . "<br>";
        chop($param_list) if substr($param_list,-1) eq ",";
        #print "Param List: $param_list<br>Site Id: $site_id<br>" if $testing == 1;

        $host_st =  DBI->connect("DBI:Pg:database=$db_name_st;host=$db_host_st;port='$pg_port'", "$db_user_st","$db_pass_st", {PrintError => 1, RaiseError => 0, AutoCommit => 1});

        my ($site_sql, $site_result, $site_record);
        $site_sql = "select iid from $db_schema_st.site where site_id = '$site_id'";
        #print "SQL = $site_sql<br>" if $testing == 1;

        $site_result = $host_st->prepare($site_sql);
        $site_result->execute();
        $site_record = $site_result->fetchrow_hashref();
        my $this_site_iid = $site_record->{'iid'};
        #print "Found site iid $this_site_iid<br>" if $testing == 1;


        my ($attrib_sql, $attrib_result, $attrib_record);
        $attrib_sql =
                "select * " .
                "from $db_schema_st.site_attrib_list sal " .
                "where sal.attrib_type_id in ($param_list) " .
                "order by attrib_type_id, seq";

        #print "SQL = $attrib_sql<br>" if $testing == 1;

        $attrib_result = $host_st->prepare($attrib_sql);
        $attrib_result->execute();
        my $total_rows = 0;
        while ($attrib_record = $attrib_result->fetchrow_hashref())
                {
                #print "$attrib_record->{'attrib_type_id'} $attrib_record->{'seq'} " .
                #       "$attrib_record->{'description'}<br>";

                my $ins_sql =
                "insert into $db_schema_st.site_attribs " .
                        "(attrib_type_id, ".
                        "attrib_list_id, ".
                        "site_iid, ".
                        "seq, ".
                        "description, ".
                        "command, ".
                        "value_list)" .
                        "VALUES " .
                        "($attrib_record->{'attrib_type_id'}, " .
                        "$attrib_record->{'id'}, " .
                        "$this_site_iid, " .
                        "'$attrib_record->{'seq'}', " .
                        "'$attrib_record->{'description'}', " .
                        "'$attrib_record->{'command'}', " .
                        "'$attrib_record->{'value_list'}')" ;

                #print "Insert SQL = $ins_sql<br>";

                my $rows = $host_st->do($ins_sql);
                $total_rows = $total_rows + $rows;

                }
        print "Total Attributes Added to Site Transition: $total_rows<br>";
        #print "=====Exiting create_site_attribs=====<br>";
        return 0;
    }
