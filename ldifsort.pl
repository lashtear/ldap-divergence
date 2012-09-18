#! /usr/bin/perl -w

# This is a structural ldif sort, by Emily Backes, based on the
# ldifsort.pl idea by Kartik Subbarao.

# License is BSD3, if I figure out where I put that boilerplate.

use strict;
use warnings;

use Net::LDAP::Util qw(canonical_dn);
use MIME::Base64;

my ($ldiffile) = @ARGV;
die "usage: $0 ldiffile\n" unless defined $ldiffile;

open(LDIFH, $ldiffile) or die "$ldiffile: $!\n";

sub read_positions {
    local $/ = ""; # break on empty lines
    my $pos = 0;
    my @valuepos;

    seek (LDIFH, 0, 0);
    while (<LDIFH>) {
	s/\n //gsm; # unwrap
	if (my ($b64, $dn) = (/^dn(::?) (.*)$/m)) {
	    $dn = decode_base64($dn) if $b64 eq '::';
	    push @valuepos,
	      (canonical_dn (lc ($dn), reverse => 1) . "\0" . $pos);
	}
	$pos = tell;
    }
    return \@valuepos;
}

sub output_ldif {
    my $valuepos = shift;
    local $/ = ""; # break on empty lines

    foreach (sort @$valuepos) {
	my ($value, $pos) = split /\0/;
	seek (LDIFH, $pos, 0);
	my $entry = <LDIFH>;

	$entry =~ s/\n //gsm; # unwrap
	my @lines = split /\n/, $entry;
	my $dnline = shift @lines;
	if (my ($b64, $dn) = ($dnline =~ /^dn(::?) (.*)$/m)) {
	    $dn = decode_base64($dn) if $b64 eq '::';
	    print "dn: ",
	      canonical_dn (lc ($dn),
			    casefold => 'lower',
			    mbcescape => 1), "\n";
	}
	print
	  map {
	      my ($attr, $val) = @$_;
	      $val =~ /^\s+/ or $val =~ /\s$/ or $val =~ /[^ -~]/ ?
		"$attr:: " . encode_base64($val, '') . "\n" :
		  "$attr: $val\n"
	      } sort {
		  join ("\0", @$a) cmp join ("\0", @$b)
	      } map {
		  my ($attr, $b64, $val) = (/^([^:]+)(::?) ?(.*)$/);
		  $attr = lc $attr;
		  $val = decode_base64 ($val) if $b64 eq '::';
		  [$attr, $val]
	      } @lines;
	print "\n";
    }
}

output_ldif (read_positions ());
