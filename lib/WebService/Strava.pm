package WebService::Strava;
use v5.010;
use strict;
use warnings;
use autodie;
use Moo;
use Method::Signatures;
use Data::Dumper;
use Carp qw(croak);

our $DEBUG = $ENV{STRAVA_DEBUG} || 0;

# ABSTRACT: Access Strava via version 3 of the API

# VERSION: Generated by DZP::OurPkg:Version

=head1 SYNOPSIS

    use WebService::Strava;

    my $strava = WebService::Strava->new();

=head1 DESCRIPTION

Provides an abstraction layer to version 3 of the  Strava API. L<http://strava.github.io/api/v3/>.

Attempts to provide a few logical shortcut methods and provide simple OAuth2 abstraction to take
the hassle out of accessing it in a scripted manner.

You can use the cli client to provide an easy setup after configuring api access in you strava profile
L<https://www.strava.com/settings/api>

  strava --setup

Which can also be called within your script via

  $strava->auth->setup();

=cut

use WebService::Strava::Auth;

has 'auth' => (
  is => 'ro',
  isa => sub { "WebService::Strava::Auth" },
  lazy => 1,
  builder => 1,
  handles => [ qw( get post ) ],
);

method _build_auth() {
  return WebService::Strava::Auth->new();
}

=method athlete

  $strava->athlete([$id]);

Takes an optional id and will retrieve a L<WebService::Strava::Athlete> 
with details Athlete retrieved. Currently authenticated user will be
returned unless an ID is provided.

=cut

use WebService::Strava::Athlete;

method athlete($id?) {
  return WebService::Strava::Athlete->new(id =>$id, auth => $self->auth);
}

=method clubs

  $strava->clubs([1]);

Returns an arrayRef of L<WebService::Strava::Club> for the currently
authenticated user. Takes an optional 1 or 0 (default 0) that will retrieve
all club details.

After instantiation it is possible to retrieve members associated with the club.

  my $club = @{$strava->clubs()}[0];
  $club->list_members([page => 2], [activities => 100]);

Returns an arrayRef athletes for the Club. Takes 2 optional
parameters of 'page' and 'members' (per page).

The results are paginated and a maximum of 200 results can be returned
per page.

=cut

method clubs($build = 0) {
  my $data = $self->auth->get_api("/athlete/clubs");
  my $index = 0;
  foreach my $club (@{$data}) {
    @{$data}[$index] = WebService::Strava::Club->new(id => $club->{id}, auth => $self->auth, _build => $build);
    $index++;
  }
  return $data;
}

=method segment

  $strava->segment($id);

Takes an mandatory id and will retrieve a
L<WebService::Strava::Segment> with details about the Segment ID retrieved.

After instantiation it is possible to retrieve efforts listed for that segment. It 
takes 3 optional named parameters of 'athlete_id', 'page' and 'efforts'.

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

use WebService::Strava::Segment;

method segment($id) {
  return WebService::Strava::Segment->new(id =>$id, auth => $self->auth);
}

=method list_starred_segments

  $segment->list_starred_segments([page => 2], [activities => 100])

Returns an arrayRef of starred L<WebService::Strava::Segment> objects for the current authenticated user. Takes 2 optional
parameters of 'page' and 'activities' (per page).

The results are paginated and a maximum of 200 results can be returned
per page.

=cut

method list_starred_segments(:$activities = 25, :$page = 1) {
  # TODO: Handle pagination better use #4's solution when found.
  my $data = $self->auth->get_api("/segments/starred?per_page=$activities&page=$page");
  my $index = 0;
  foreach my $segment (@{$data}) {
    @{$data}[$index] = WebService::Strava::Segment->new(id => $segment->{id}, auth => $self->auth, _build => 0);
    $index++;
  }
  return $data;
}

=method effort

  $strava->effort($id);

Takes an mandatory id and will retrieve a
L<WebService::Strava::Athlete::Segment_Effort> with details about the Segment Effort ID retrieved.

=cut

use WebService::Strava::Athlete::Segment_Effort;

method effort($id) {
  return WebService::Strava::Athlete::Segment_Effort->new(id =>$id, auth => $self->auth);
}

=method activity

  $strava->activity($id);

Takes an mandatory id and will retrieve a
L<WebService::Strava::Athlete::Activity> with details about the Activity ID retrieved.

=cut

use WebService::Strava::Athlete::Activity;

method activity($id) {
  return WebService::Strava::Athlete::Activity->new(id =>$id, auth => $self->auth);
}

=method list_activities

  $athlete->list_activities([page => 2], [activities => 100], [before => 1407665853], [after => 1407665853]);

Returns an arrayRef of L<WebService::Strava::Athlete::Activity> objects 
for the current authenticated user. Takes 4 optional parameters of 'page', 
'activities' (per page), 'before' (activities before unix epoch),
and 'after' (activities after unix epoch).

The results are paginated and a maximum of 200 results can be returned
per page.

=cut

method list_activities(:$activities = 25, :$page = 1, :$before?, :$after?) {
  # TODO: Handle pagination better use #4's solution when found.
  my $url = "/athlete/activities?per_page=$activities&page=$page";
  $url .= "&before=$before" if $before;
  $url .= "&after=$after" if $after;
  my $data = $self->auth->get_api("$url");
  my $index = 0;
  foreach my $activity (@{$data}) {
    @{$data}[$index] = WebService::Strava::Athlete::Activity->new(id => $activity->{id}, auth => $self->auth, _build => 0);
    $index++;
  }
  return $data;
}

=method list_friends_activities

  $athlete->list_activities([page => 2], [activities => 100])

Returns an arrayRef activities for friends of the current authenticated user. Takes 2 optional
parameters of 'page' and 'activities' (per page).

The results are paginated and a maximum of 200 results can be returned
per page.

=cut

method list_friends_activities(:$activities = 25, :$page = 1) {
  # TODO: Handle pagination better use #4's solution when found.
  my $data = $self->auth->get_api("/activities/following?per_page=$activities&page=$page");
  my $index = 0;
  foreach my $activity (@{$data}) {
    @{$data}[$index] = WebService::Strava::Athlete::Activity->new(id => $activity->{id}, auth => $self->auth, _build => 0);
    $index++;
  }
  return $data;
}

=method upload_activity

  $strava->upload_activity(
    file => '/path/to/sample.gpx', 
    type => 'gpx'
  );

Uploads an activity to Strava. Returns an upload status hash. Takes
the following named arguments: 

=over

=item file

Expected to be a path to the file being uploaded.

=item type

The Strava api accepts following file types:  fit, fit.gz, tcx, 
tcx.gz, gpx and  gpx.gz. There is no current logic to detect what 
sort is being uploaded (patches welcome), so you will need to set 
it which ever file your uploading. ie 'gpx' for a GPX file.

=item activity_type

Optional, case insensitive string of following types (list may be 
out of date check L<http://strava.github.io/api/v3/uploads/#post-file> 
for up to date info): ride, run, swim, workout, hike, walk, 
nordicski, alpineski, backcountryski, iceskate, inlineskate, kitesurf, 
rollerski, windsurf, workout, snowboard, snowshoe. Type detected from 
file overrides, uses athlete’s default type if not specified.

=item name

Optional string, if not provided, will be populated using start date 
and location, if available.

=item description

Optional. Left blank if not provided.

=item private

Sets the Activity to Private.

=item trainer

Optional integer, activities without lat/lng info in the file are 
auto marked as stationary, set to 1 to force.

=item external_id

Optional string, data filename will be used by default but should 
be a unique identifier.

=back

=cut

method upload_activity(
  :$file, 
  :$type = 'gpx', 
  :$activity_type?,
  :$name?,
  :$description?,
  :$private?,
  :$trainer?,
  :$external_id?,
) {
  my $data = $self->auth->uploads_api(
    file => $file, 
    type => $type, 
    activity_type => $activity_type,
    name => $name, 
    description => $description, 
    private => $private, 
    trainer => $trainer, 
    external_id => $external_id, 
  );
  return $data;
}

=method upload_status

  $strava->upload_status(id => '12345678');

Given an upload id (returned by uploading an activity) you can check 
the status of the request. Takes between 5 and 10 seconds for an 
to be processed so keep in mind  there isn't any point in checking 
more than once per second.

=cut

method upload_status(:$id) {
  my $data = $self->auth->get_api("/uploads/$id");
  return $data;
}

=method delete_activity

  $strava->delete_activity(id => '12345678');

Will delete a given activity. Returns true on success and false 
upon failure

=cut

method delete_activity(:$id) {
  my $data = $self->auth->delete_api("/activities/$id");
  return $data;
}

=head1 ACKNOWLEDGEMENTS

Fred Moyer <fred@redhotpenguin.com> - Giving me Co-Maint on WebService::Strava

Paul Fenwick <pjf@cpan.org> - For being generally awesome, providing inspiration,
assistance and a lot of boiler plate for this library.


=head1 BUGS/Feature Requests

Please submit any bugs, feature requests to
L<https://github.com/techamn83/WebService-Strava3/issues> .

Contributions are more than welcome! I am aware that Dist::Zilla comes with quite a dependency chain, so feel free to submit pull request with code + explanation of what you are trying to achieve and I will test and likely implement them.

=cut

1;
