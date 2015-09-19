package WebService::Strava::Segment;

use v5.010;
use strict;
use warnings;
use Moo;
use Method::Signatures;
use Scalar::Util qw(looks_like_number);
use Scalar::Util::Reftype;
use Carp qw(croak);
use experimental 'switch';
use Data::Dumper;

# ABSTRACT: A Strava Segment Object

# VERSION: Generated by DZP::OurPkg:Version

=head1 SYNOPSIS

  my $segment = WebService::Strava::Segment->new( auth => $auth, id => '229781' );

=head1 DESCRIPTION

  Upon instantiation will retrieve the segment matching the id.
  Requires a pre-authenticated WebService::Strava::Auth object.

=cut

# Validation functions

my $Num = sub {
  croak "$_[0] isn't a number" unless looks_like_number $_[0];
};

my $Ref = sub {
  croak "auth isn't a 'WebService::Strava::Auth' object!" unless $_[0]->isa("WebService::Strava::Auth");
};

my $Bool = sub {
  croak "$_[0] must be 0|1" unless $_[0] =~ /^[01]$/;
};

# Debugging hooks in case things go weird. (Thanks @pjf)

around BUILDARGS => sub {
  my $orig  = shift;
  my $class = shift;
  
  if ($WebService::Strava::DEBUG) {
    warn "Building task with:\n";
    warn Dumper(\@_), "\n";
  }
  
  return $class->$orig(@_);
};

# Authentication Object
has 'auth'            => ( is => 'ro', required => 1, isa => $Ref );

# Defaults + Required
has 'id'                    => ( is => 'ro', required => 1, isa => $Num );
has '_build'                => ( is => 'ro', default => sub { 1 }, isa => $Bool );

# Segment API
has 'name'                  => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'activity_type'         => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'distance'              => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'average_grade'         => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'maximum_grade'         => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'elevation_high'        => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'elevation_low'         => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'start_latlng'          => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'end_latlng'            => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'climb_category'        => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'city'                  => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'state'                 => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'country'               => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'private'               => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'starred'               => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'map'                   => ( is => 'ro', lazy => 1, builder => '_build_segment' );
has 'athlete_count'         => ( is => 'ro', lazy => 1, builder => '_build_segment' ); 
has 'resource_state'        => ( is => 'ro', lazy => 1, builder => '_build_segment' ); 
has 'effort_count'          => ( is => 'ro', lazy => 1, builder => '_build_segment' ); 
has 'total_elevation_gain'  => ( is => 'ro', lazy => 1, builder => '_build_segment' ); 

sub BUILD {
  my $self = shift;

  if ($self->{_build}) {
    $self->_build_segment();
  }
  return;
}

method _build_segment() {
  my $segment = $self->auth->get_api("/segments/$self->{id}");
 
  foreach my $key (keys %{ $segment }) {
    given ( $key ) {
      when      ("athlete")   { $self->_instantiate("Athlete", $key, $segment->{$key}); }
      default                 { $self->{$key} = $segment->{$key}; }
    }
  }

  return;
}

use WebService::Strava::Athlete;

method _instantiate($type, $key, $data) {
  $self->{$key} = "WebService::Strava::$type"->new(auth => $self->auth, id => $data->{id}, _build => 0);
  return;
}

=method retrieve()

  $segment->retrieve();

When a Segment object is lazy loaded, you can call retrieve it by calling
this method.

=cut

method retrieve() {
  $self->_build_segment();
}

=method list_efforts()

  $segment->list_efforts([athlete_id => 123456], [page => 2], [efforts => 100], [raw => 1])'

Returns the Segment efforts for a particular segment. Takes 4 optional
parameters of 'athlete_id', 'page', 'efforts' and 'raw'. Raw will return the 
an array segment_effort data instead of L<WebService::Strava::Athlete::Segment_Effort>
objects.

  * 'athelete_id' will return the segment efforts (if any) for the athelete
    in question.

The results are paginated and a maximum of 200 results can be returned
per page.

=cut

method list_efforts(:$efforts = 25,:$page = 1,:$athlete_id, :$raw = 0) {
  # TODO: Handle pagination better #4
  my $data;
  if ($athlete_id) {
    $data = $self->auth->get_api("/segments/$self->{id}/all_efforts?per_page=$efforts&page=$page&athlete_id=$athlete_id");
  } else {
    $data = $self->auth->get_api("/segments/$self->{id}/all_efforts?per_page=$efforts&page=$page");
  }
  
  if (! $raw) {
    my $index = 0;
    foreach my $effort (@{$data}) {
      @{$data}[$index] = WebService::Strava::Athlete::Segment_Effort->new(id => $effort->{id}, auth => $self->auth, _build => 0);
      $index++;
    }
  }

  return $data;
};

=method leaderboard

  $segment->leaderboard(
    [page => 2], 
    [activities => 100], 
    [gender => M|F], 
    [following => 1|0], 
    [clubid => 123456], 
    [date_range => 'this_year'|'this_month'|'this_week'|'today'], 
    [age_group => '0_24'|'25_34'|'35_44'|'45_54'|'55_64'|'65_plus'],
    [weight_class => |'0_124'|'125_149'|'150_164'|'165_179'|'180_199'|'200_plus'|'0_54'|'55_64'|'65_74'|'75_84'|'85_94'|'95_plus']);

Returns the leaderboard for the current segment. Takes a number of optional parameters 
including 'page' and 'activities' (per page). For more information regarding the leaderboard
information visit the api documentation L<http://strava.github.io/api/v3/segments/#leaderboard>

The results are paginated and a maximum of 200 results can be returned
per page.

=cut

method leaderboard(:$activities = 25, :$page = 1, :$gender?, :$age_group?, :$weight_class?, :$following?, :$club?, :$date_range?, ) {
  # TODO: Handle pagination better use #4's solution when found.
  my $url = "/segments/$self->{id}/leaderboard?per_page=$activities&page=$page";
  $url .= "&age_group=$age_group" if $age_group;
  $url .= "&gender=$gender" if $gender;
  $url .= "&weight_class=$weight_class" if $weight_class;
  $url .= "&following=$following" if $following;
  $url .= "&club=$club" if $club;
  $url .= "&date_range=$date_range" if $date_range;
  return $self->auth->get_api("$url")->{entries};
}

1;
