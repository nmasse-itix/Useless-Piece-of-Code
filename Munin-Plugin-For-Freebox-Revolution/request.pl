#!/usr/bin/perl -w

use LWP::UserAgent;
use JSON::PP;
use MIME::Base64;
use Digest::SHA qw/hmac_sha1_hex/;
use Data::Dumper;
use strict;

# Consider the RRD data for the last 5 minutes
my $interval = 5*60;
my $debug = 0;
my %db_fields = (
  net => [ qw/bw_up bw_down rate_up rate_down/ ],
  temp => [ qw/cpum cpub sw hdd fan_speed/ ], 
  dsl => [ qw/rate_up rate_down snr_up snr_down/ ],
);

my %graph = (
  net => { 
    graph_category => 'Network',
    graph_args => '--base 1000 -l 0',
    graph_scale => 'yes',
    graph_info => 'The upload and download rate of the Freebox Revolution.',
    (map { 
      ("$_.info" => ($_ =~ m/^up/ ? "Upstream " : "Downstream ") . ($_ =~ m/rate/ ? "Rate" : "Bandwidth"), 
      "$_.type" => "GAUGE", 
      "$_.label" => "bytes/s" )
    } qw/bw_up bw_down rate_up rate_down/),
    '.db' => "net",
  },
  temp => {
    graph_category => 'Sensors',
    graph_args => '--base 1000 -0',
    graph_scale => 'no',
    graph_info => 'The temperature of various sensors on the Freebox Revolution',
    (map { 
      ("$_.warning" => "70", 
      "$_.critical" => "80",
      "$_.info" => "Temperature of the $_ component",
      "$_.type" => "GAUGE",
      "$_.label" => "°C" )
    } qw/cpum cpub sw hdd/),
    '.db' => "temp",
  },
  fan => {
    graph_category => 'Sensors',
    graph_args => '--base 1000 -0',
    graph_scale => 'no',
    graph_info => 'The fan speed of the Freebox Revolution',
    (map { 
      ("$_.info" => "Fan speed",
      "$_.type" => "GAUGE",
      "$_.label" => "RPM" )
    } qw/fan_speed/),
    '.db' => "temp",
  },
  dsl_rate => {
    graph_category => 'Network',
    graph_args => '--base 1000 -l 0',
    graph_scale => 'yes',
    graph_info => 'The xDSL rate stats of the Freebox Revolution',
    (map { 
      ("$_.info" => ($_ =~ m/^up/ ? "Upstream " : "Downstream ") . "Rate", 
      "$_.type" => "GAUGE", 
      "$_.label" => "kb/s")
    } qw/rate_up rate_down/),
    '.db' => "dsl",
  },
  dsl_snr => {
    graph_category => 'Network',
    graph_args => '--base 1000 -l 0',
    graph_scale => 'no',
    graph_info => 'The xDSL SNR stats of the Freebox Revolution',
    (map {
      ("$_.info" => ($_ =~ m/^up/ ? "Upstream " : "Downstream ") . "SNR Ratio", 
      "$_.type" => "GAUGE", 
      "$_.label" => "dB")
    } qw/snr_up snr_down/),
    '.db' => "dsl",
  },
);

sub get_json {
  my $resp = shift;
  my $method = shift;
  #warn "raw response: ".$resp->decoded_content;
  warn "$method: www: ".$resp->status_line
    unless $resp->is_success;
  my $json = decode_json($resp->decoded_content);
  die "$method: api: method call failed: ".$json->{msg}
    unless $json->{success};
  return $json;
}

# Determine which graph is asked by munin
my @mode = grep { $0 =~ m/fb_${_}/ } keys %graph;
die "please symlink this script with a valid suffix (",(join ",", keys %graph),"). Exemple: fb_net. "
  unless @mode;
my $mode = $mode[0];
warn "mode is $mode" if $debug;

# Print out config when asked to do so
my $arg = shift;
my $graph_info = $graph{$mode};
my @fields = sort map { m/\.info/ ? m/(.*)\./ : () } keys %{$graph_info};
if (defined $arg and $arg eq 'config') {
  print "graph_order ", (join " ", @fields), "\n";
  foreach my $key (sort grep /^[^.]/, keys %{$graph_info}) {
    print $key, " ", $graph_info->{$key}, "\n";
  }
  exit 0;
}

my $ua = LWP::UserAgent->new;

my $auth_response = $ua->get("http://mafreebox.freebox.fr/api/v1/login/");
my $json_auth_response = get_json($auth_response, "login");
my $challenge = $json_auth_response->{result}->{challenge};
warn "Current challenge is $challenge" if $debug;

my $filename = "apptoken";
open TOKENFILE, "<", $filename
  or die "open: $filename: $!";
my $apptoken = <TOKENFILE>;
close TOKENFILE;

my $pw = hmac_sha1_hex($challenge, $apptoken);
warn "Computed password is $pw" if $debug;

my %auth_request = (
  app_id => "fr.itix.munin",
  password => $pw
);

# Get a session token
$auth_response = $ua->post("http://mafreebox.freebox.fr/api/v1/login/session", Content => encode_json(\%auth_request));
$json_auth_response = get_json($auth_response, "session");
my $session_token = $json_auth_response->{result}->{session_token};
die "post: session: no session_token in response" 
  unless defined $session_token;

# Use it in follwowing calls
$ua->default_header('X-Fbx-App-Auth', $session_token);

# Do not forget to logout
END {
  if (defined $session_token) {
    my $logout_response = $ua->post("http://mafreebox.freebox.fr/api/v1/login/session", Content => encode_json(\%auth_request));
    my $json_logout_response = get_json($auth_response, "session");
  }
}

my $db = $graph_info->{'.db'};
my %json_request = (
  db => $db,
  date_start => time - $interval,
  date_end => time,
  fields => \@fields,
);

# Get actual values
my $rest_response = $ua->post("http://mafreebox.freebox.fr/api/v1/rrd", Content => encode_json(\%json_request));
my $json_rrd_response = get_json($rest_response, "rrd_$db");
  
my %sum;
my $count = 0;
foreach my $data (@{$json_rrd_response->{result}->{data}}) {
  foreach my $field (@fields) {
    my $value = $data->{$field};
    $sum{$field} = 0
      unless exists $sum{$field};
    $sum{$field} += $value;
  }
  $count++;
}

# Average every result
while (my ($field, $sum) = each(%sum)) {
  my $average = int($sum / $count);
  print "${db}_${field}.value $average\n";
}

exit 0

