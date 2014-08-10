package WebService::Strava::Auth;

use v5.010;
use strict;
use warnings;
use Moo;
use Method::Signatures;
use Config::Tiny;
use LWP::Authen::OAuth2;
use JSON qw(decode_json encode_json);
use JSON::Parse 'valid_json';
use Carp qw(croak);
use Data::Dumper;

# ABSTRACT: A Strava Segment Object

# VERSION: Generated by DZP::OurPkg:Version

=head1 SYNOPSIS

  my $auth = WebService::Strava::Auth->new(
    ['config_file' => '/path/to/file'], 
    ['scope' => 'read']
  );

=head1 DESCRIPTION

  A thin wrapper around LWP::Authen::OAuth2 to provide a pre-authenticated Oauth2 object
  as a helper for the rest of WebService::Strava.

=cut

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

has 'api_base'      => (is => 'ro', default => sub { 'https://www.strava.com/api/v3' });
has 'config_file'   => ( is => 'ro', default  => sub { "$ENV{HOME}/.stravarc" } );
has 'config'        => ( is => 'rw', lazy => 1, builder => 1 );
has 'scope'         => ( is => 'ro', default  => sub { "view_private,write" } );
has 'auth'          => ( is => 'rw', lazy => 1, builder => 1, handles => [ qw( get post ) ] );

# TODO: Potentially allow the config to be passed through instead of loaded.
#has 'client_id'     => ( is => 'ro' );
#has 'client_secret' => ( is => 'ro' );
#has 'token_string'  => ( is => 'rw' );

=method setup()

  $auth->setup();

Runs through configuring Oauth2 authentication with the Strava API. You
will need your client_id and client_secret available here:

https://www.strava.com/settings/api

=cut

method setup() {
  # Request Client details if non existent
  if (! $self->config->{auth}{client_id} ) {
    $self->config->{auth}{client_id} = $self->prompt("Paste enter your client_id");
  }
  
  if (! $self->config->{auth}{client_secret} ) {
    $self->config->{auth}{client_secret} = $self->prompt("Paste enter your client_secret");
  }
  
  # Build auth object - TODO: Write a strava authentication provider! Issue #1
  my $oauth2 = LWP::Authen::OAuth2->new(
    client_id => $self->{config}{auth}{client_id},
    client_secret => $self->{config}{auth}{client_secret},
    service_provider => "Strava",
    redirect_uri => "http://127.0.0.1",
    scope => $self->{scope},
  );

  # Get authentican token string
  say "Log into the Strava account and browse the following url\n";
  my $url = $oauth2->authorization_url();
  say $url;
  my $code = $self->prompt("Paste code result here");
  $oauth2->request_tokens(code => $code);
  $self->config->{auth}{token_string} = $oauth2->token_string;
  $self->config->write($self->{config_file});
}

method _build_config() {
  my $config;
  if ( -e $self->{config_file} ) {
    $config = Config::Tiny->read( $self->{config_file} );
    unless ($config->{auth}{client_id} 
            && $config->{auth}{client_id}) {
      die <<"END_DIE";
Cannot find user credentials in $self->{config_file}

You'll need to have a $self->{config_file} file that looks like 
the following:

    [auth]
    client_id     = xxxxx
    client_secret = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

You can get these values by going to https://www.strava.com/settings/api

Running 'strava setup' or \$strava->auth->setup will run you through
setting up Oauth2.

END_DIE
}
  } else {
    $config = Config::Tiny->new();
  }
  return $config;
}

method _build_auth() {
  $self->config;
  my $oauth2 = LWP::Authen::OAuth2->new(
    client_id => $self->{config}{auth}{client_id},
    client_secret => $self->{config}{auth}{client_secret},
    service_provider => "Strava",
    token_string => $self->config->{auth}{token_string},
  );
  return $oauth2;
}

=method get_api

  $strava->auth->get_api($url);

Mainly used for an internal shortcut, but will return a parsed
perl data structure of what the api returns.

=cut

method get_api($api_path) {
  my $response = $self->auth->get($self->{api_base}.$api_path);
  my $json = $response->decoded_content;
  if (! valid_json($json) ) {
    if ($ENV{STRAVA_DEBUG}) {
      say Dumper($json);
    }
    croak("Something went wrong, a JSON string wasn't returned");
  }
  return decode_json($json);
}


method prompt($question,:$default) { # inspired from here: http://alvinalexander.com/perl/edu/articles/pl010005
  if ($default) {
    say $question, "[", $default, "]: ";
  } else {
    say $question, ": ";
    $default = "";
  }

  $| = 1;               # flush
  $_ = <STDIN>;         # get input

  chomp;
  if ("$default") {
    return $_ ? $_ : $default;    # return $_ if it has a value
  } else {
    return $_;
  }
}

1;
