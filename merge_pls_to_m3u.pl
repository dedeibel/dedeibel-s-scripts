#!/usr/bin/perl -w
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

use strict;

if (@ARGV < 2) {
	print "$0: outfile.m3u input.pls ...\n";
	exit 0;
}

my $sort = 1;

my $outputFilename = shift;

open OUT, "> $outputFilename" or die "Open: $!";
print OUT "#EXTM3U\n";

my %entries;
my $expected_total = 0;
my $playlists = 0;

while (<>)
{
  chomp;
	tr/\x0D//d;
  
  if (m#\[playlist\]#) {
    $playlists++;
  }
  my ($key, $value) = split(/=/, $_);
  next unless ($key && $value);
  
  if ($key eq 'NumberOfEntries') {
    $expected_total += $value;
  }

  if ($key =~ m#File(\d+)#) {
    $entries{"$playlists-$1"}->{file} = $value;
  }
  if ($key =~ m#Title(\d+)#) {
    $entries{"$playlists-$1"}->{title} = $value;
  }
}

my @entries;
if ($sort) {
  @entries = sort { ($a->{title} || '') cmp ($b->{title} || '') } values %entries;
}
else {
  @entries = values %entries;
}

local $| = 1;
foreach my $entry (@entries) {
    if ($entry->{title} && $entry->{file}) {
		  print ".";
    }
    elsif ($entry->{file}) {
      print '/';
      $entry->{title} = 'unkown';
    }
    else {
      print "x";
    }

		printf OUT "#EXTINF:-1,%s\n%s\n", $entry->{title}, $entry->{file};
}

print "\n";
print "Tracks found: ". scalar(keys %entries) ."\n";
