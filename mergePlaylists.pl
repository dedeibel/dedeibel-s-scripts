#!/usr/bin/perl -w
#
# Merges a couple of .pls playlist files into one
# big m3u file.
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

my $outputFilename = shift;

open OUT, "> $outputFilename" or die "Open: $!";

print OUT "#EXTM3U\n";

my $count = 0;
my $errors = 0;

my $number = 0;
my $url;
my $title;

while (<>)
{
	chomp;
	if (m#^File(\d+)=#) {
		$url = $';
		$url =~ tr/\x0D//d;
	}
	elsif (m#^Title(\d+)=#) {
		$title = $';
		$title =~ tr/\x0D//d;
	}
	else {
		next;
	}

	if ($number) {
		if ($1 != $number) {
			$errors++;
			print STDERR "Warning, not matching pair found ($1)|($number) in $ARGV\n";
		}
	}
	else {
		$number = $1;
	}

	if ($url and $title) {
		$count++;
		$number = 0;
		print ".";
		print OUT "#EXTINF:-1,$title\n$url\n";
		$title = undef;
		$url = undef;
	}
}

print "\n";
print "Tracks found: $count\n";
print "Errors:       $errors\n";
