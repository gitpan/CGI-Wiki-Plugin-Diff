use strict;
use CGI::Wiki;
use CGI::Wiki::TestConfig::Utilities;
use Test::More tests =>
  (1 + 9 * $CGI::Wiki::TestConfig::Utilities::num_stores);

use_ok( "CGI::Wiki::Plugin::Diff" );

my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
    SKIP: {
      skip "$store_name storage backend not configured for testing", 9
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = CGI::Wiki->new( store => $store );
      my $differ = eval { CGI::Wiki::Plugin::Diff->new; };
      is( $@, "", "'new' doesn't croak" );
      isa_ok( $differ, "CGI::Wiki::Plugin::Diff" );
      $wiki->register_plugin( plugin => $differ );

      # Test ->null diff
      my %nulldiff = $differ->differences(
      			node => "Jerusalem Tavern",
      			left_version => 1,
      			right_version => 1);
      ok( !exists($nulldiff{diff}), "Diffing the same version returns empty diff");
      
      # Test ->body diff
      my %bodydiff = $differ->differences(
      			node => "Jerusalem Tavern",
      			left_version => 1,
      			right_version => 2);
      is( @{$bodydiff{diff}}, 2, "Differ returns 2 elements for body diff");
      is_deeply( $bodydiff{diff}[0], {
      			left => '',
      			right => "== Line 1 ==\n"},
      		"First element is line number on right");
      is_deeply( $bodydiff{diff}[1], {
      			left => '<span class="diff1">Pub </span>'.
      				'in Clerkenwell with St Peter\'s beer.'.
      				"<BR />category='Pubs'",
      			right => '<span class="diff2">Tiny pub </span>'.
      				'in Clerkenwell with St Peter\'s beer.'.
      				'<span class="diff2"> <br />'.
      				"\nNear Farringdon station</span>".
      				"<BR />category='Pubs'",
      				},
      		"Differences highlights body diff with span tags");
      		
      # Test ->meta diff
      my %metadiff = $differ->differences(
      			node => "Jerusalem Tavern",
      			left_version => 2,
      			right_version => 3);
      is( @{$metadiff{diff}}, 2, "Differ returns 2 elements for meta diff");
      is_deeply( $metadiff{diff}[0], {
      			left =>  "== Line 1 ==\n",
      			right => "== Line 1 ==\n"},
      		"First element is line number on right");
      is_deeply( $metadiff{diff}[1], {
      			left => "Near Farringdon station".
      				"<BR />category='Pubs'",
      			right => "Near Farringdon station".
      				"<BR />category='Pubs".
      				'<span class="diff2">,Real Ale\'<br />'.
      				"\nlocale='Farringdon</span>'",
      				},
      		"Differences highlights metadata diff with span tags");
      		
    } # end of SKIP
}
