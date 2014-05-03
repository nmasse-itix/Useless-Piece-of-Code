#!/usr/bin/perl -w

use LWP::UserAgent;
use JSON::PP;
use MIME::Base64;
use Digest::SHA qw/hmac_sha1_hex/;
use strict;

my $ua = LWP::UserAgent->new;

sub get_json {
  my $resp = shift;
  my $method = shift;
  #warn "raw response: ".$resp->decoded_content;
  warn "$method: www: ".$resp->status_line
    unless $resp->is_success;
  my $json = decode_json($resp->decoded_content);
  die "$method: fb: method call failed: ".$json->{msg}
    unless $json->{success};
  return $json;
}

my $auth_response = $ua->get("http://mafreebox.freebox.fr/api/v1/login/");
my $json_auth_response = get_json($auth_response, "login");
my $challenge = $json_auth_response->{result}->{challenge};
print "Current challenge is $challenge\n";

my $filename = "apptoken";
open TOKENFILE, "<", $filename
  or die "open: $filename: $!";
my $apptoken = <TOKENFILE>;
close TOKENFILE;

my $pw = hmac_sha1_hex($challenge, $apptoken);
print "Computed password is $pw\n";

my %auth_request = (
  app_id => "fr.itix.munin",
  password => $pw
);

$auth_response = $ua->post("http://mafreebox.freebox.fr/api/v1/login/session", Content => encode_json(\%auth_request));
$json_auth_response = get_json($auth_response, "login");
my $session_token = $json_auth_response->{result}->{session_token};
die "post: session: no session_token in response" 
  unless defined $session_token;

$ua->default_header('X-Fbx-App-Auth', $session_token);
my %rrd_request = (
  db => "net",
  date_start => time - 5*60,
  date_end => time,
);
my $rrd_response = $ua->post("http://mafreebox.freebox.fr/api/v1/rrd", Content => encode_json(\%rrd_request));
my $json_rrd_response = get_json($rrd_response, "rrd");

