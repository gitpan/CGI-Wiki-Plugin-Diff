use strict;

use CGI::Wiki::TestConfig::Utilities;
use CGI::Wiki;

use Test::More tests => $CGI::Wiki::TestConfig::Utilities::num_stores;

# Add test data to the stores.
my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
    SKIP: {
      skip "$store_name storage backend not configured for testing", 1
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = CGI::Wiki->new( store => $store );

      $wiki->write_node( "Jerusalem Tavern",
			 "Pub in Clerkenwell with St Peter's beer.",
			 undef,
			 { category => [ "Pubs" ]
			 }
		       );

      my %j1 = $wiki->retrieve_node( "Jerusalem Tavern");

      $wiki->write_node( "Jerusalem Tavern",
                         "Tiny pub in Clerkenwell with St Peter's beer. 
Near Farringdon station",
                         $j1{checksum},
                         { category => [ "Pubs" ]
                         }
                       );

      my %j2 = $wiki->retrieve_node( "Jerusalem Tavern");

      $wiki->write_node( "Jerusalem Tavern",
                         "Tiny pub in Clerkenwell with St Peter's beer. 
Near Farringdon station",
                         $j2{checksum},
                         { category => [ "Pubs", "Real Ale" ],
                           locale => [ "Farringdon" ]
                         }
                       );

      pass "$store_name test backend primed with test data";

    } # end of SKIP
}
