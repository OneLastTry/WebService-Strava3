package WebService::Strava::Auth::Browser;

use v5.010;
use strict;
use warnings;
use experimental 'say';
use Moo;
use Method::Signatures;
use Browser::Open;
use HTTP::Server::Brick;
use File::Spec;

extends 'WebService::Strava::Auth';

# ABSTRACT: Oauth2 authentication for Strava.

# VERSION: Generated by DZP::OurPkg:Version

=head1 SYNOPSIS

  my $auth = WebService::Strava::Auth::Browser->new(
    ['config_file' => '/path/to/file'],
    ['scope' => 'read'],
    ['browser' => '/path/to/browser'],
    ['port' => '8080'],
  );

=cut

has 'port'    => (is => 'ro', default => 8080);
has 'browser' => (is => 'ro', required => 0);

=method setup()

  $auth->setup();

Runs through configuring Oauth2 authentication with the Strava API. You
will need your client_id and client_secret available here:

https://www.strava.com/settings/api

This method differs from the method in L<WebService::Strava::Auth> by firing up
a web browser to open the authentication URL automatically. This method also
loads a web server using L<HTTP::Server::Brick>, which receives the code from
authentication.

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
    redirect_uri => "http://127.0.0.1:" . $self->port,
    scope => $self->{scope},
  );

  # Start up an HTTP server to listen to the redirect
  my $server_pid = open my $server_in, q{-|};
  if($server_pid == 0){
    my $devnull = File::Spec->devnull;
    open my $nul, q{>}, $devnull;

    my $server = HTTP::Server::Brick->new(
      port => $self->port,
      error_log => $nul,
      access_log => $nul,
    );
    $server->mount('/', {handler => sub {
        my ($req, $res) = @_;
        $res->add_content("Authenticated. You can close this tab now.");
        my %query = $req->uri->query_form;
        my $token = $query{code};
        $|++;
        print $token, "\n";
        1;
    }});
    $server->start;
  }elsif(defined($server_pid)){
    if(!$self->browser){
      Browser::Open::open_browser($oauth2->authorization_url());
    }else{
      system $self->browser, $oauth2->authorization_url();
    }
    my $code = <$server_in>;
    kill 'HUP', $server_pid;
    chomp $code;

    $oauth2->request_tokens(code => $code);
    $self->config->{auth}{token_string} = $oauth2->token_string;
    $self->config->write($self->{config_file});
    wait;
  }else{
    die "Couldn't fork to start web server: $!";
  }
}

1;