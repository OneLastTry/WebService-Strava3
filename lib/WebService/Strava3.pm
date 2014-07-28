package WebService::Strava3;
use v5.010;
use strict;
use warnings;
use autodie;
use Moo;
use JSON::Any;
use WWW::Mechanize;
use Data::Dumper;

our $DEBUG = 0;

use constant API_BASE => 'https://www.strava.com/api/v3';

# ABSTRACT: Access Strava Activities via version 3 of the API

# VERSION: Generated by DZP::OurPkg:Version

sub _build_json  { return JSON::Any->new;      }

=head1 SYNOPSIS

    use WebService::Strava3;

    my $strava = WebService::Strava3->new );

    my $runs = $zombies->efforts_raw;

=head1 DESCRIPTION

