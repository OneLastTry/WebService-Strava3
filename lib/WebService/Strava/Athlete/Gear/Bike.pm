package WebService::Strava::Athlete::Gear::Bike;

use v5.010;
use strict;
use warnings;
use Moo;

extends 'WebService::Strava::Athlete::Gear';

# ABSTRACT: An Athlete's Bike

# VERSION: Generated by DZP::OurPkg:Version

=head1 SYNOPSIS

  Provides a Bike object

=head1 DESCRIPTION

  Though currently gear items can only be retrieved if Strava
  extend the API to be able to update/change/remove gear, this
  will provide the framework to easily extend the library.

=cut

has 'frame_type' => ( is => 'ro' );

1;
