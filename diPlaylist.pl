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
use FileHandle;
use Cwd;

#
# I use this script to automatically fill amarok with the
# playlist, so just enter your player's command here, or
# leave it false.
#
# $application = 'amarok';
$application = '';

$tmp = '/tmp/diPlaylist';
$threads = 3;
$start=getcwd;
if ( -e $tmp)
{
    print "Temp dir '$tmp' allready exists, exiting\n";
    exit;
}

print "+++ Creating temp directory.\n";
mkdir $tmp;
if ( ! -d $tmp )
{
    print "Could not create temp dir '$tmp'\n";
    exit;
}

chdir $tmp;
print "+++ Getting di.fm homepage.\n";
`wget di.fm`;
print "+++ Finding .pls files.\n";
open(INFILE, '< index.html') or die "Could not open 'index.html'";

@OUTFILES = [];
for ($num = 0; $num < $threads; ++$num)
{
   $OUTFILES[$num] = new FileHandle;
   $OUTFILES[$num]->open("> list-$num") or die "Could not open output file 'list-$num'";
}
$count = 0;
$outfile = 0;
while (<INFILE>)
{
   if (m/href="(.*?mp3.*?.pls)"/)
   {
         $a = $1;
         if (substr($a,0,1) eq "/")
         {
             $a = "http://di.fm" . $a;
         }

        if ($outfile >= $threads) { $outfile = 0 };
        $OUTFILES[$outfile]->print("$a\n");
        ++$outfile;
        ++$count;
   }
}
foreach $a (@OUTFILES) { $a->close; }
print "+++ Download .pls files ($count) with $threads processes\n";
for ($t = 0; $t < $threads; ++$t)
{
   if (fork == 0) {
      print "*** download thread $t running.\n";
      chdir $tmp;
      `wget -i list-$t`;
      print "*** download thread $t done.\n";
      exit;
   }
}
while (wait() != -1) {};
print "+++ Children done, creating m3u playlist.\n";
`mergePlaylists.pl distreams.m3u *.pls*`;
if ($application) {
  `$application distreams.m3u`;
}
else {
  `mv $tmp/distreams.m3u $start`
}

chdir "/tmp";
`rm -rf "$tmp"`;

print "+++ Done.\n";
