#!/usr/bin/perl -w
#
# Holt die aktuelle playlist von sunshine-live.de
# oder für das angegebene Datum
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

use lib ("$ENV{HOME}/perl_lib");

# Einstellen der debug Stufen, 1 wenig, 2 mehr Infos
my $DEBUG = 0;

####
#
# Using
#
####
use strict;
use LWP;
use Time::Local;
use Sunshine;

#
# Gibt die uebergebenen Titel auf stdout aus.
# 
# Parameter:
#   1: Array von hashes mit Liste der Titel oder undef, wenn
#      die Seite nicht erreicht werden konnte.
#
sub printResult($)
{
	my $tracks  = shift;
	my $first   = 1;
	
    # Die Seite konnte nicht geladen werden
	if (!$tracks)
    {
		print STDERR 	"Sorry, konnte die sunshine-live Seite ",
						"nicht erreichen.\n";
	}
    # Es konnte keine Tracks gefunden werden
	elsif (@$tracks == 0)
    {
		print 	"Sorry, zum angegeben Zeitpunkt liegen ",
				"keine Titel vor.\n";
	}
    # Es sind Tracks in der Liste, gib sie aus
	else {
		foreach my $track(@$tracks)
        {
			print 	$track->{'zeit'}, "   ", $track->{'artist'} ," - ",
					$track->{'titel'}, "\n";

		}

		$first = 0;
	} # else
}

sub printHelp()
{
    print "Usage $0: [hh:mm] [dd.mm[.yyyy]]\n";
}

#
# Main Funktion des Programms
#
# Parameter:
#   1: Referenz auf das Argumentlistenarray
#
sub main($)
{
	my $arg  = shift;
	my @ARGV = @$arg;

	my ($datum, $sekunden, $uhrzeit, $stunde, $minute);
	
	foreach (@ARGV) {
		next if not defined;

        #
        # Hilfeausgabe gefordert
        #
		if ($_ eq "-h" or $_ eq "--help") {
			printHelp();
			exit 0;
		}
        #
        # Nur Tag und Monat wurde angegeben, ergaenze den Rest
        #
		elsif (m/^(\d{1,2})\.(\d{1,2})$/) {
            # Hole dir das aktuelle Jahr
			my @time  = localtime();
			my $year  = $time[5];
			   $year += 1900;

            # Baue das Datum neu zusammen, mm.dd.yyyy
            # Stelle sicher, dass es zweistellig ist
			$datum  = sprintf("%02u.%02u", $1, $2);
			$datum .= ".$year";

            # Hole die Sekunden repraesentation zum Angegeben Zeitpunkt
			$sekunden = timelocal(0, 0, 0, $1, $2-1, $year);
		}
        #
        # Tag, Monat und Jahr wurden angegeben
        #
		elsif (m/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/) {
            # Baue das Datum neu zusammen, mm.dd.yyyy
            # Stelle sicher, dass es zweistellig ist
			$datum    = sprintf("%02u.%02u.%u", $1, $2, $3);

            # Hole die Sekunden repraesentation zum Angegeben Zeitpunkt
			$sekunden = timelocal(0, 0, 0, $1, $2-1, $3);
		}
        #
        # Die Uhrzeit wurde angegeben
        #
		elsif(m/^\d{1,2}:\d{1,2}$/) {
            # Uebernimm die Zeitangabe
			$uhrzeit = $_;
		}
		else {
			print "Unbekannter Parameter '$_'\n";
			printHelp();
			exit 4;
		}
	}

    #
    # Falls kein Datum angegeben wurde, nimm das aktuelle
    #
	if (not $datum) {
		my @time = localtime(time());
		$sekunden = timelocal(0, 0, 0, @time[3,4,5]);

		# Datum aufpolieren, mm.dd.yyyy
		$time[4]++;
		$time[5] += 1900;
		$datum    = sprintf("%02u.%02u.%u", @time[3,4,5]);
	}

    #
    # Falls keine Uhrzeit angegeben wurde, nimm die aktuelle
    #
	if (not $uhrzeit) {
		my @time = localtime(time());
		$minute  = $time[1];
		$stunde  = $time[2];
	}
    #
    # Falls die Uhrzeit angegeben wurde, extrahiere Stunden und Minuten
    #
	else {
		($stunde, $minute) = split(/:/, $uhrzeit, 2);
		$stunde = int $stunde;
		$minute = int $minute;
	}

	# Minuten nur als vielfaches von 5,
    # runde auf oder ab.
	my $mod = $minute % 10;
	if (($mod != 0) or ($mod != 5))
	{
		if ($mod < 5) { $minute -= $mod;}
		else {          $minute -= ($mod - 5);}
	}

	if ($DEBUG) {
		print STDERR "main: Datum $datum - $sekunden\n";
	}

	if ($DEBUG) {
		print STDERR "main: Uhrzeit $stunde:$minute\n";
	}

    # Setzte den Debug Modus des Moduls
	Sunshine::setDebug($DEBUG);

    # Hole die Playlist und gibt das Ergebnis aus
	printResult(Sunshine::getPlaylistPage($stunde, $minute, $sekunden));
}

main(\@ARGV);
