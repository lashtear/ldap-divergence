#! /usr/bin/perl -w
# $Id: ldifsort.pl,v 1.2 2004/03/05 21:42:36 acctmgr Exp $

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
        1 while s/^(dn:.*)?\n /$1/m; # Handle line continuations
        my $value;
        if (/^dn(::?) (.*)$/m) {
            $value = $2;
            $value = decode_base64($value) if $1 eq '::';
        }
        push @valuepos, (canonical_dn (lc ($value),
                                       reverse => 1) . "\0" . $pos);
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
#        print "\# $value\n";
        print $entry;
        print "\n" if $entry !~ /\n\n$/;
    }
}

output_ldif (read_positions ());
