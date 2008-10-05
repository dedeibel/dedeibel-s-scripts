
#
# Modul zum holen der Playlist von
# sunshine-live.de
#
# Sa Dez  3 14:49:39 CET 2005
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

package Sunshine;

use LWP;
use Time::Local;

use strict;

require Exporter;

my @ISA 	  = qw(Exporter);
my @EXPORT	  = qw(getPage getTitles getPlaylistPage getNow);

my @VERSION	= 1.0;


# Default values
my $DEBUG = 0;

# Playlist URL,
# Hardcoded, wenn die Seite sich aendert, wird sich wohl auch
# das Skript aendern muessen.
my $sunshine = 'http://www.sunshine-live.de/index.php?id=15';

my $defaultAgent = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.10) Gecko/20050825 Firefox/1.0.4';

#
# Laed eine http Seite
#
# Parameter:
#   1:  Komplette URL als string
#   2:  User agent string oder undef fuer default (Mozilla)
#
sub getPage($;$)
{
	my $url = shift;
	my $userAgent = shift || $defaultAgent;

	my $ua = new LWP::UserAgent;
	$ua->agent($userAgent);

	my $request = HTTP::Request->new(GET => $$url);
	   $request->content_type('application/x-www-form-urlencoded');

	# Hole die Antwort
	my $response = $ua->request($request);

	if ($response->is_success)
	{
		if ($DEBUG == 2) {
			print STDERR "getPage: -----------------------\n",
					$response->content(), "\n---------------------------\n";
		}
		return \$response->content();
	}
	else {
		if ($DEBUG) {
			print STDERR "getPage: ", $response->status_line, "\n";
		}
		print STDERR "Konnte die Sunshine-live Seite nicht erreichen.\n";
		return 0;
	}
}

#
# Fischt die Titel aus der Playlist Seite und gibt einen Hash zurueck
# 
# Parameter:
#   1:  Komplette homepage als string
#
sub getTitles($)
{
    my $page = shift();

	my %track  = ();
	my @result = ();
	
	my $inTable = 0;
	my $inTitleBlock = 0;

    #
    # Man haette sicher einen html parser verwenden koennen, jedoch
    # ist dies der Ursprung des Skriptes und waere auch etwas overkill.
    #

    foreach (split(/\n/, $$page)) {
        next if not defined;

		if ($inTable) {
            #
            # Der Bereich der Seite in dem die Titel stehen
            # wurde erreicht.
            #
			if ($inTitleBlock) {
                # Zeit eines Titels
				if (m#<td class="time">(.*?)</td>$#) {
                	print STDERR "getTitles:		Zeit gefunden.\n" if $DEBUG;
					$track{zeit} = $1;
				}
                # Name des tracks
				elsif (m#<td class="title">(.*?)</td>$#) {
                	print STDERR "getTitles:		Titel gefunden.\n" if $DEBUG;

					if ($1) {
						$track{titel} = $1;
					}
					else {
						$track{titel} = 'Unbekannt';
					}
				}
                # Artist des tracks
				elsif (m#<td class="artist">(.*?)</td>$#) {
                	print STDERR "getTitles:		Artist gefunden.\n" if $DEBUG;

					if ($1) {
						$track{artist} = $1;
					}
					else {
						$track{artist} = 'Unbekannt';
					}
				}

                # Ende des tracks
				if (m#</tr>#) {
					if ($DEBUG) {
						while (my ($key, $value) = each %track) {
							print STDERR "getTitles:		»$key« => »$value«\n";
						}
					}

                	print STDERR "getTitles:	Verlasse Titelblock\n" if $DEBUG;
					$inTitleBlock = 0;

					push (@result, {%track}) if (exists $track{zeit}) ;
					%track = ();
				}
			}
            # 
            # Anfang des Titelblocks der Seite gefunden
            #
			elsif (m#<tr>$#) {
                print STDERR "getTitles:	Titelblock gefunden\n" if $DEBUG;
				$inTitleBlock = 1;
			}

            #
            # Ende der Playlist Tabelle gefunden
            #
			if (m#</TABLE>#) {
                print STDERR "getTitles: Verlasse Tabelle\n" if $DEBUG;
				$inTable = 0;
			}
		}
        #
        # Playlist Tabelle gefunden
        #
        elsif (m/<table class="showPlaylist" cellpadding="0" cellspacing="0">$/o) {
            print STDERR "getTitles: Tabelle gefunden\n" if $DEBUG;
			$inTable = 1;
		}
    }

    # Sortiere die tracks nach Zeit
	@result = sort {$b->{zeit} cmp $a->{zeit}} @result;

    return \@result;
}

# Fragt die Playlist fuer die uebergeben Zeit
# Stunde, Minute, Sekunde ab, der letzte Parameter
# ist der http user agent, optional default Mozilla
sub getPlaylistPage($$$;$)
{
	my $stunde = shift;
	my $minute = shift;
	my $sekunden  = shift;
	my $userAgent = shift || $defaultAgent;

	my $ua = new LWP::UserAgent;
	$ua->agent($userAgent);

	my $request = HTTP::Request->new(POST => $sunshine);
	   $request->content_type('application/x-www-form-urlencoded');
	   $request->content("datum=$sekunden&zeit_h=$stunde&zeit_m=$minute&SUBMIT=anzeigen");

	# Hole die Antwort
	my $response = $ua->request($request);

	if ($response->is_success)
	{
		if ($DEBUG == 2) {
			print STDERR "getPlaylistPage: --------------------------\n",
							$response->content(), "\n--------------------------\n";
		}

		my $result = getTitles(\$response->content());

		return $result;
	}
	else {
		if ($DEBUG) {
			print STDERR "getPlaylistPage: ", $response->status_line, "\n";
		}
		print STDERR "Konnte die Sunshine-live Seite nicht erreichen.\n";
		return 0;
	}
}

# Gibt ein Array mit Stunden, Minute, Sekunde zurueck im
# Format fuer die Abfrage bei sunshine-live
sub getNow()
{
	my ($datum, $sekunden, $uhrzeit, $stunde, $minute);

	my @time = localtime(time());
	$sekunden = timelocal(0, 0, 0, @time[3,4,5]);

	# Datum aufpolieren
	$time[4]++;
	$time[5] += 1900;
	$datum    = sprintf("%02u.%02u.%u", @time[3,4,5]);
	
	$minute  = $time[1];
	$stunde  = $time[2];
	
	# Minuten nur als vielfaches von 5
	my $mod = $minute % 5;
	if ($mod != 0)
	{
		$minute -= $mod;
	}

	if ($DEBUG) {
		print STDERR "getNow: Datum $datum - $sekunden\n";
	}

	if ($DEBUG) {
		print STDERR "getNow: Uhrzeit $stunde:$minute\n";
	}

	my @array = ($stunde, $minute, $sekunden);
	return @array;
}

sub setDebug($)
{
	$DEBUG = shift;
}

1;
