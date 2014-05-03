#!/usr/bin/perl -w

use LWP::UserAgent;
use JSON::PP;
use strict;

my $ua = LWP::UserAgent->new;

my %auth_request = (
  app_id => "fr.itix.munin",
  app_name => "Munin",
  app_version => "0.0.1",
  device_name => "tournedix.itix.fr"
);

my $auth_response = $ua->post("http://mafreebox.freebox.fr/api/v1/login/authorize", Content => encode_json(\%auth_request));

die "post: authorize: ".$auth_response->status_line
  unless $auth_response->is_success;

my $json_auth_response = decode_json($auth_response->decoded_content);
my $trackid = $json_auth_response->{result}->{track_id};
die "post: authorize: no trackid in response" 
  unless defined $trackid;

my $apptoken = $json_auth_response->{result}->{app_token};
print "APPTOKEN is '",$apptoken,"'\n";

do {
  $auth_response = $ua->get("http://mafreebox.freebox.fr/api/v1/login/authorize/$trackid");
  die "post: authorize: ".$auth_response->status_line
    unless $auth_response->is_success;
  $json_auth_response = decode_json($auth_response->decoded_content);
  
  print "RES: ",$json_auth_response->{success}," STATUS: ",$json_auth_response->{result}->{status}, "\n";
  sleep 2;
} while ($json_auth_response->{result}->{status} eq 'pending');

my $status = $json_auth_response->{result}->{status};
print "Final status is '", $status, "'\n";

if ($status eq 'granted') {
  my $filename = "apptoken";
  open TOKENFILE, '>', $filename
    or die "open: $filename: $!";
  print TOKENFILE "$apptoken\n";
  close TOKENFILE;
}

