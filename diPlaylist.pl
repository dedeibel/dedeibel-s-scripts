#!/usr/bin/perl
#
# Fetches the latest .pls playlist files from di.fm and
# creates one big m3u playlist.
#
# Copyright (c) 2008, Benjamin Peter <BenjaminPeter@arcor.de>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the author nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY Benjamin Peter ''AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Benjamin Peter BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
use LWP;
use HTTP::Request;
use HTTP::Response;
use HTTP::Headers;
use FileHandle;
use Cwd;

#
# I use this script to automatically fill amarok with the
# playlist, so just enter your player's command here, or
# leave it false.
#
# $application = '';

my $user_agent = "Mozilla/5.0 (;;;;) Gecko/2009021906 Firefox/3.0.7";

$tmp = '/tmp/diPlaylist';
$threads = 3;
$start=getcwd;

sub main {
  print "+++ Creating temp directory.\n";
  mkdir $tmp;
  if ( ! -d $tmp )
  {
      print "Could not create temp dir '$tmp'\n";
      exit;
  }
  
  chdir $tmp;
  print "+++ Getting di.fm homepage.\n";
  my $dipage = fetch_url('http://di.fm/');
  die "Got an empty page from di.fm" unless $dipage;
  print "+++ Finding .pls files.\n";
  
  $OUTFILES = [];
  $count = 0;
  $outfile = 0;
  foreach (split("\n", $dipage))
  {
     if (m/href="(.*?mp3.*?.pls)"/)
     {
           $a = $1;
           if (substr($a,0,1) eq "/")
           {
               $a = "http://di.fm" . $a;
           }
  
          if ($outfile >= $threads) { $outfile = 0 };
          push (@{$OUTFILES->[$outfile]}, $a);
          ++$outfile;
          ++$count;
     }
  }
  print "+++ Download .pls files ($count) with $threads processes\n";
  for ($t = 0; $t < $threads; ++$t)
  {
     if (fork == 0) {
        print "*** download thread $t running.\n";
        chdir $tmp;
        get_files($OUTFILES->[$t]);
        print "*** download thread $t done.\n";
        exit;
     }
  }
  get_files(["http://metal-only.de/listen.pls"]);
  while (wait() != -1) {};
  print "\n";
  print "+++ Children done, creating m3u playlist.\n";
  `merge_pls_to_m3u.pl distreams.m3u *.pls*`;
  
  print "+++ Done.\n";
}

sub fetch_url {
  my ($url) = @_;

  # Create a user agent object
  use LWP::UserAgent;
  $ua = LWP::UserAgent->new;
  $ua->agent($user_agent);

  # Create a request
  my $req = HTTP::Request->new(GET => $url);

  # Pass request to the user agent and get a response back
  my $res = $ua->request($req);

  # Check the outcome of the response
  if ($res->is_success) {
      return $res->content;
  }
  else {
      die "Could not fetch '$url':", $res->status_line, "\n";
  }
}

sub get_files {
  my ($urls) = @_;

  # Create a user agent object
  use LWP::UserAgent;
  $ua = LWP::UserAgent->new;
  $ua->agent($user_agent);

  foreach my $url (@$urls) {
    # Create a request
    my $req = HTTP::Request->new(GET => $url);

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    # Check the outcome of the response
    if ($res->is_success) {
        local $| = 0;
        next unless $res->content;
        my $filename;
        if ($url =~ m#/([^/]+)$#) {
          $filename = $1;
        }
        else {
          $filename = "rand-". rand() . ".pls";
        }
        open(OUT, ">".$filename) or die "Could not write temporary playlist to: ".$filename;
        print OUT $res->content;
        close OUT;
        print ".";
    }
    else {
        die "Could not fetch '$url':", $res->status_line, "\n";
    }
  }
}

#
# Start
#

if ( -e $tmp)
{
    print "Temp dir '$tmp' allready exists, exiting\n";
    exit;
}

eval {
  main();
};
if ($@) {
  print STDERR "Exiting unexpectedly: $@\nSystem Error: $!\n";
}
else {
  if ($application) {
    eval {
      `$application distreams.m3u`;
    };
    if ($@) {
     print STDERR "Exiting unexpectedly: $@\nSystem Error: $!\n";
    }
  }
  else {
    `mv $tmp/distreams.m3u $start`
  }
}
  
chdir "/tmp";
`rm -rf "$tmp"`; 

