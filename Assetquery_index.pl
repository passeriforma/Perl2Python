#!/usr/bin/perl

#use lib "/usr/lib64/perl5";
use lib "/usr/local/lib64/perl5/DBD";
use CGI;
use DBI;
use DBD::Pg;
use DBD::Sybase;
use Data::Dumper;
use strict;

chomp(my $server_name = `/bin/uname -n`); # find out production or dev

   my $db_name;
   my $db_host;
   my $db_user;
   my $db_pass;
   my $host;
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
   my $db_host_ipw;
   my $db_name_ipw;
   my $db_user_ipw;
   my $db_pass_ipw;

# set env for production or dev
if ( $server_name eq 'webapps' ) {
    $db_name="viaremotecap";
#    $db_host="storageops1.arsenaldigital.com";
    $db_host="postgresdbs.bcrs-vaults.ibm.com";
    $db_user="viaremotecap";
    $db_pass="v18r3m0t3c8p";
#    $db_pass="viaremotecap";
    $host = $db_host;
    # for ticketing system SDE
    $db_name_sde="SDE";
    $db_host_sde="SDESQL";
#    $db_user_sde="readonly";
#    $db_pass_sde="JustBr0w\$ing";
    $db_user_sde="readonly";
    $db_pass_sde='C0gn0$14!';
    $host_sde = $db_host_sde;
    # for Mediation
    $db_name_medi = "pmedi";
    $db_user_medi = "readonly";
    $db_pass_medi = "readonly01";

    $db_host_ipw="postgresdbs";
    $db_name_ipw="adswipdb";
    $db_user_ipw="ipadmin";
    $db_pass_ipw="1p8dm1n";
} # end if $server_name
else {
    $db_name="viaremotecap";
    $db_host="localhost";
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

#my $prog_name="assetquery.pl";
my $prog_name="https://assetquery.bcrs-vaults.ibm.com";
my $html = new CGI;

my $host_name = $html->param('SearchHost');
my $SearchHostButton = $html->param('Search');
#my $FFIECButton = $html->param('Search');
my $DetailButton = $html->param('DetailButton');
my $radiobutton = $html->param('searchtype');



my $dbh = DBI->connect("DBI:Pg:database=$db_name;host=$db_host;port='5433'", "$db_user",
          "$db_pass", {PrintError => 1, RaiseError => 0, AutoCommit => 1});

#my $dsn="dbi:JDBC:hostname=10.1.10.35:1523;url=jdbc:sqlserver://10.1.10.41:1488;instanceName=SDE;databasename=SDE;ssl=require";
#my $dsn="DBI:Sybase:databasename=$db_name_sde;host=$db_host_sde;port='1488'";
#my $dbh_sde = DBI->connect("$dsn", "$db_user_sde", "$db_pass_sde", {PrintError => 1});
#    die "Unable for connect to server $DBI::errstr"
#    unless $dbh_sde;

my $dbh_sde = DBI->connect("dbi:Sybase:server=SDE", "$db_user_sde", "$db_pass_sde", {PrintError => 1});
die "Unable for connect to server $DBI::errstr"
    unless $dbh_sde;

$dbh_sde->do("use SDE");

my %labels = (
   'FFIEC' => 'List FFIEC Infrastructure',
   'IP' => 'Prod NetBlock (X.X.X)',
   'ILO' => 'ILO NetBlock (X.X.X)',
   'Host' => 'Hostname',
   'Serial' => 'Device Serial #' );

print $html->header;
print $html->start_html(-title=>'Asset Query',-style=>{'src'=>'/Apache/htdocs/css/style.css'} );
print "<table align=center cellspacing=0 cellpadding=3>\n";
  print "<tr><td style='text-align:center;color:#0033CC;font-family:Arial;font-size:24px;font-weight:bold'>IPS Asset query page</td>\n";
  print "</tr></table>\n";
print $html->start_form(-name=>"assetquery",-action=>"$prog_name",-method=>"POST");
print $html->p("Please select what you want to query from the options below.");
print $html->p("note that the Prod IP and ILO IP will query the IP Web page, not the asset database.");
print $html->h4("Also, note that the FFIEC button does not need a search value. Please leave the search field blank when using this option.");
print "<table border=0>\n";
  print "<tr><td>\n";
#   print $html->radio_group(-name=>'searchtype',-values=>['Host','IP','ILO','FFIEC],-default=>'Host');
   print $html->radio_group(-name=>'searchtype',-values=>\%labels,-linebreak=>'true',-default=>'Host');
   print $html->p("Please enter a search term:");
   print $html->textfield(-name=>'SearchHost', -value=>"$host_name");
  print "<tr><td>".$html->submit(-name=>'Search',-value=>'Search');
print "</table>\n";
print $html->end_form();
print $html->hr();

 if ( $SearchHostButton eq 'Search' && $radiobutton eq 'FFIEC') {
   chomp(my @FFIEC_hosts = `cat ffiec_hosts.txt`);
   chomp(my @FFIEC_infra = `cat ffiec_infra.txt`);
   my $host_list = join(",",@FFIEC_hosts);
   my $infra_list = join(",",@FFIEC_infra);

   my $q2='SELECT "ADSW-Machine Name","Asset IP","Asset Description","Serial #","ADSW-OUTOFBANDIP",a."Status:" ';
      $q2=$q2.'from "_SMDBA_"."Inventory Items" a, ';
      $q2=$q2.'"_SMDBA_"."Configurations" b ';
      $q2=$q2.'WHERE a."Seq.Configuration" = b."Sequence" ';
      $q2=$q2.'AND "ADSW-Machine Name" IN '."($host_list)";

     my $sth = $dbh_sde->prepare($q2);
      $sth->execute() or die print $html->p($DBI::errstr);
      print $html->h3("FFIEC Regulated Servers");
      print "<table border=1>\n";
       print "<th>Host</th><th>IP</th><th>Description</th><th>Serial</th><th>ILO</th><th>Status</th>\n";
       while ( my($machine,$ip,$description,$sernum,$ilo,$status) = $sth->fetchrow_array() )
       {
         print $html->start_form(-name=>"queryresults",-action=>"$prog_name",-method=>"POST");
          print "<tr style='font-family:Arial;text-align:center'><td>$machine<td>$ip<td>$description<td>$sernum<td>$ilo<td>$status<td>".$html->submit(-value=>"$machine Detail",-name=>'DetailButton');
       }
       print "</td></tr>\n";
      print $html->end_form();
      print "</table>\n";
      $sth->finish();

   my $q3='SELECT "ADSW-Machine Name","Asset IP","Asset Description","Serial #","ADSW-OUTOFBANDIP",a."Status:" ';
      $q3=$q3.'from "_SMDBA_"."Inventory Items" a,';
      $q3=$q3.' "_SMDBA_"."Configurations" b ';
      $q3=$q3.'WHERE a."Seq.Configuration" = b."Sequence" ';
      $q3=$q3.'AND "ADSW-Machine Name" IN '."($infra_list)";

     my $sth2 = $dbh_sde->prepare($q3);
      $sth2->execute() or die print $html->p($DBI::errstr);
      print $html->h3("FFIEC Regulated Infrastructure (Firewalls/Switches)");
      print "<table border=1>\n";
       print "<th>Host</th><th>IP</th><th>Description</th><th>Serial</th><th>ILO</th><th>Status</th>\n";
       while ( my($machine,$ip,$description,$sernum,$ilo,$status) = $sth->fetchrow_array() )
       {
         print $html->start_form(-name=>"queryresults",-action=>"$prog_name",-method=>"POST");
          print "<tr style='font-family:Arial;text-align:center'><td>$machine<td>$ip<td>$description<td>$sernum<td>$ilo<td>$status<td>".$html->submit(-value=>"$machine Detail",-name=>'DetailButton');
      }
      print $html->end_form();
      print "</table>\n";
 } # Close FFIEC if
 if ( $SearchHostButton eq 'Search' && $radiobutton eq 'Host') {
     my $q1;
     if( $host_name eq "" ){
        $q1='SELECT "ADSW-Machine Name","Asset IP","Asset Description","Serial #","ADSW-OUTOFBANDIP","Status:"';
         $q1=$q1.'from "_SMDBA_"."Inventory Items"';
         $q1=$q1.'ORDER By "Status:"';
     } else {
        $q1='SELECT "ADSW-Machine Name","Asset IP","Asset Description","Serial #","ADSW-OUTOFBANDIP","Status:" ';
         $q1=$q1.'from "_SMDBA_"."Inventory Items" ';
         $q1=$q1.'WHERE "ADSW-Machine Name" like '."'%$host_name%'";
     }

     my $sth = $dbh_sde->prepare($q1);
      $sth->execute() or die print $html->p($DBI::errstr);
      print "<table border=1>\n";
       print "<th>Host</th><th>IP</th><th>Description</th><th>Serial</th><th>ILO</th><th>Status</th>\n";
       while ( my($machine,$ip,$description,$sernum,$ilo,$status) = $sth->fetchrow_array() )
       {
         print $html->start_form(-name=>"queryresults",-action=>"$prog_name",-method=>"POST");
          print "<tr style='font-family:Arial;text-align:center'><td>$machine<td>$ip<td>$description<td>$sernum<td>$ilo<td>$status<td>".$html->submit(-value=>"$machine Detail",-name=>'DetailButton');
          print "</td></tr>\n";
       } # end while
      print $html->end_form();
      print "</table>\n";

 } elsif($SearchHostButton eq 'Search' && $radiobutton eq 'IP'){

     my $dbh_ipw = DBI->connect("DBI:Pg:database=$db_name_ipw;host=$db_host_ipw;port='5432'", "$db_user_ipw", "$db_pass_ipw", {PrintError => 1, RaiseError => 0, AutoCommit => 0});

     die "$DBI::errstr" unless($dbh_ipw);
     my($O1, $O2, $O3, $O4) = split('\.',$host_name,4);
          if ((length($O1)) < 3){
             while ((length($O1)) < 3){
                $O1 = "0" . $O1;
             }
          }

          if ((length($O2)) < 3){
             while ((length($O2)) < 3){
                $O2 = "0" . $O2;
             }
          }

          if ((length($O3)) < 3){
             while ((length($O3)) < 3){
                $O3 = "0" . $O3;
             }
          }

          my $newip = $O1 . "." . $O2 . "." . $O3;

     my $q2='select a."ip_address",a."subnet_address",a."machine_name",a."machine_desc",a."monitor",a."device_type", b."idc" ';
        $q2=$q2.'from "ip_list" a, ';
        $q2=$q2.'"ip_subnets" b ';
        $q2=$q2.'where a."subnet_address" = b."subnet_address" ';
        $q2=$q2.'and a."subnet_address" like '."'%$newip%'";
        $q2=$q2.' ORDER BY a."ip_address"';

       my $sth = $dbh_ipw->prepare($q2);
        $sth->execute() or die print $html->p($DBI::errstr);
        print "<table border=1>\n";
         print "<th>IP</th><th>Subnet</th><th>Site</th><th>Host</th><th>Description</th><th>Monitor</th><th>Type</th>\n";
         while ( my($ip,$subn,$mchne,$desc,$mon,$type,$idc) = $sth->fetchrow_array() ) {
           print $html->start_form(-name=>"queryresults",-action=>"$prog_name",-method=>"POST");
            print "<tr style='font-family:Arial;text-align:center'><td>$ip<td>$subn<td>$idc<td>$mchne<td>$desc<td>$mon<td>$type";
            print "</td></tr>\n";
         } # end while
      print $html->end_form();
      print "</table>\n";

     $dbh_ipw->disconnect();
 } elsif($SearchHostButton eq 'Search' && $radiobutton eq 'ILO'){

     my $dbh_ipw = DBI->connect("DBI:Pg:database=$db_name_ipw;host=$db_host_ipw;port='5432'", "$db_user_ipw", "$db_pass_ipw", {PrintError => 1, RaiseError => 0, AutoCommit => 0});

     die "$DBI::errstr" unless($dbh_ipw);
     my($O1, $O2, $O3, $O4) = split('\.',$host_name,4);
          if ((length($O1)) < 3){
             while ((length($O1)) < 3){
                $O1 = "0" . $O1;
             }
          }

          if ((length($O2)) < 3){
             while ((length($O2)) < 3){
                $O2 = "0" . $O2;
             }
          }

          if ((length($O3)) < 3){
             while ((length($O3)) < 3){
                $O3 = "0" . $O3;
             }
          }

          my $newip = $O1 . "." . $O2 . "." . $O3;

     my $q2='select a."ip_address",a."subnet_address",a."machine_name",a."machine_desc",a."monitor",a."device_type" ';
        $q2=$q2.'from "ip_list" a ';
        $q2=$q2.'WHERE a."subnet_address" LIKE '."'%$newip%'";
        $q2=$q2.'AND a."device_type" = '."'ILO Port'";
        $q2=$q2.' ORDER BY a."ip_address"';

       my $sth = $dbh_ipw->prepare($q2);
        $sth->execute() or die print $html->p($DBI::errstr);
        print "<table border=1>\n";
         print "<th>IP</th><th>Subnet</th><th>Host</th><th>Description</th><th>Monitor</th><th>Type</th>\n";
         while ( my($ip,$subn,$mchne,$desc,$mon,$type) = $sth->fetchrow_array() ) {
           print $html->start_form(-name=>"queryresults",-action=>"$prog_name",-method=>"POST");
            print "<tr style='font-family:Arial;text-align:center'><td>$ip<td>$subn<td>$mchne<td>$desc<td>$mon<td>$type";
            print "</td></tr>\n";
         } # end while
      print $html->end_form();
      print "</table>\n";

     $dbh_ipw->disconnect();
} elsif ( $SearchHostButton eq 'Search' && $radiobutton eq 'Serial') {
     my $q1='select "ADSW-Machine Name","Asset IP","Asset Description","Serial #","ADSW-OUTOFBANDIP",a."Status:",b."Company Name" ';
      $q1=$q1.'from "Inventory Items" a, ';
      $q1=$q1.'"_SMDBA_"."Configurations" b ';
      $q1=$q1.'where a."Seq.Configuration" = b."Sequence" ';
      $q1=$q1.'and "Serial #" LIKE '."'%$host_name%'";

     my $sth = $dbh_sde->prepare($q1);
      $sth->execute() or die print $html->p($DBI::errstr);
      print "<table border=1>\n";
       print "<th>Host</th><th>IP</th><th>Description</th><th>Serial</th><th>ILO</th><th>Status</th>\n";
       while ( my($machine,$ip,$description,$sernum,$ilo,$status) = $sth->fetchrow_array() )
       {
         print $html->start_form(-name=>"queryresults",-action=>"$prog_name",-method=>"POST");
          print "<tr style='font-family:Arial;text-align:center'><td>$machine<td>$ip<td>$description<td>$sernum<td>$ilo<td>$status<td>".$html->submit(-value=>"$machine Detail",-name=>'DetailButton');
          print "</td></tr>\n";
       } # end while
      print $html->end_form();
      print "</table>\n";

}
      if($DetailButton){
         my($host,$x) = split(' ',$DetailButton);
#         my $fields = '"ADSW-Machine Name","Asset IP","Asset Description","Serial #","ADSW-OUTOFBANDIP","Status:","CFG_STREET","CFG_CITY","CFG_STATE","CFG_ZIP","CFG_COUNTRY","CFG_IP","Note","Asset TYpe","LastModified","InActive:"';
my $fields = '"ADSW-Machine Name","Asset IP","Asset Description","Serial #","ADSW-OUTOFBANDIP","Status:","CFG_STREET","CFG_CITY","CFG_STATE","CFG_ZIP","CFG_COUNTRY","CFG_IP","Asset TYpe","LastModified","InActive:"';
         my $q2='select ';
         $q2=$q2."$fields ";
         $q2=$q2.'from "_SMDBA_"."Inventory Items" ';
#         $q2=$q2.'"_SMDBA_"."Configurations" b ';
         $q2=$q2.'where "ADSW-Machine Name" LIKE '."'\%$host%'";

#      print "<h2>SQL: $q2<br></h2>\n";
      print $html->start_form(name=>"detailresults",action=>$prog_name,method=>"POST");
      print "<h1>$host Detail<br></h1>\n";
#      print "<h1>FNORD! <br></h1>\n";
     my $sth2 = $dbh_sde->prepare($q2);
      $sth2->execute();
      print "<table border=1>\n";
      my $details = $sth2->fetchrow_hashref();
      foreach my $key (sort(keys(%$details))){
         my $val = $details->{$key};
         chomp($val);
         print "<tr style='font-family:Arial;text-align:center'><th>$key</th><td>$val";
      }
      print "</td></tr>\n";
      print $html->end_form();
      print "</table>\n";
      } #end if

$dbh->disconnect();
$dbh_sde->disconnect();

