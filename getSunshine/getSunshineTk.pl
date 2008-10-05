#!/usr/bin/perl
#
# Holt die aktuelle Playlist von sunshine-live.de
# oder die für das angegebene Datum.
#
# Sa Dez  3 14:50:11 CET 2005
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

#####
# Einstellungen
#####

my $fontname = '-*-helvetica-bold-r-*-*-17-*-*-*-*-*-iso8859-1';

# Ob die größe des Fensters änderbar sein soll
# (Das Textfeld kann sich dabei nicht vergrößern/kleinern)
my $resizable = 0;

# Ob erst "Dj - Titel" oder wie auf der Sunshine-live Seite "Titel - Dj"
# angezeigt werden soll. (Bei den uptrax charts wird zum Beispiel die
# Platzierung in den Titel geschrieben und das sieht dann doof aus.)
my $dj_titel = 0;


# Minimale höhe des Textfeldes
my $minZeilen = 4;

# Minimale breite des Textfeldes
my $minBreite = 70;

# Auf 1 oder 2 gesetzt gibt das Script mehr Infos
my $DEBUG = 0;


####
#
# Using
#
####
use strict;
use LWP;
use Tk;
use Tk::ROText;
use Time::Local;

use Sunshine;

####
#
# Variablen
#
####
my $mw;
my $textfeld;
my $aktuell = 0;
my $indent = 0;

# Automatisches update
my $autoUpdate = 1;
my $timer;
my $timeout = 150000; # 2.5 Minuten in Millisekunden

# Anzeige des letzten updates
my $lastUpdate;

#
# Tk::ROText spezielisieren um Doppelklick Verhalten
# zu ändern.
#
package Tk::MyText;
use Tk::ROText;
use Tk::Derived;
use vars qw(@ISA);
@ISA = qw(Tk::ROText);
use base qw/ Tk::Derived Tk::ROText /;
Construct Tk::ROText 'MyText';

sub selectWord
{
	print STDERR "selectWord: enter\n" if ($::DEBUG);

	my $tag = $_[0];
	my $ev = $tag->XEvent;
	# Position des klicks holen
	my $cur = $tag->index($ev->xy);
	
	my @tags = $tag->tagNames($cur);
	
	# Es muss in einen mit "track" markierter Bereich geklickt werden
	# ansonsten wird die standard Methode aufgerufen.
	unless (grep {$_ eq 'track'} @tags) {
		$tag->SUPER::selectWord;
		return;
	};

	# Anfang der Zeile + Einrückung bekommen
	my $first = $tag->index("$cur linestart + ${indent}c");
	# End of the line
	my $last = $tag->index("$cur lineend");
 
	# Alles andere deselektieren und $first bis $last auswählen
 	$tag->tagRemove('sel','1.0',$first);
 	$tag->tagAdd('sel',$first,$last);
 	$tag->tagRemove('sel',$last,'end');

	print STDERR "selectWord: selecting track $first <-- $cur --> $last\n" if ($::DEBUG);
}
1;

package main;

sub setupWindow()
{
    $mw = new MainWindow();
    $mw->configure(-title => 'Sunshine-Live Playlist');
	$mw->resizable($resizable, $resizable);
       
    my $frame = $mw->Frame()->pack(-expand => 'yes', -fill => 'both', -expand => 1);
    $textfeld = Tk::MyText->new($frame, -width => $minBreite, -height => $minZeilen, -font=>$fontname);

	$textfeld->pack(-side => "top", -fill => 'both', -expand => 1);

	######
	# Markierung aktueller track
	######
	$textfeld->tagConfigure("aktuell", '-foreground' => '#008888');

	$frame = $mw->Frame()->pack(-expand => 1, -fill => 'x');

	#####
	# Letztes update
	#####
	$frame->Label(-text => 'Letztes update:')->pack(-side => 'left', -anchor => 'w');
	$frame->Label(-textvariable => \$lastUpdate, -relief => 'sunken', -width => 7)->pack(-side => 'left', -anchor => 'w');

	#####
	# Auto refresh
	#####
	$frame->Checkbutton(-text => 'Auto update', -variable => \$autoUpdate, -onvalue => 1, -offvalue => 0)->pack(-side => 'left', -anchor => 'w');

	#####
	# Buttons
	#####
	$frame->Button(-text => 'Beenden', -command => sub { exit })->pack(-side => 'right', -anchor => 'e');
	$frame->Button(-text => 'Update', -command => [ \&refreshResult, 1 ])->pack(-side => 'right', -anchor => 'e');

}

#
# Setzt den timeout bis zum naechsten update der Anzeige
# auf die angegebenen Sekunden.
#
# Parameter:
#   1: Sekunden bis zum refresh
#
sub setTimeout($)
{
	my $force = shift;
	$timer->cancel() if $force;

	if ($DEBUG) {
		printf STDERR "setTimeout: timeout %d\n", $timeout;
	}

	$timer = $mw->after($timeout, \&refreshResult);
}

#
# Holt eine neue Track Liste und gibt sie in der GUI aus
#
sub refreshResult
{
	my $force = 0;
	$force = shift if @_;

	return if not ($autoUpdate or $force);

	# Uhrzeit auf volle 5 minuten gerundet
	my @now 	= Sunshine::getNow();
	# die aktuelle Zeit
	my @current = localtime(time());

	$aktuell = 1;
	$lastUpdate = sprintf("%02d:%02d", $current[2], $current[1]);
	printResult(Sunshine::getPlaylistPage($now[0], $now[1], $now[2]));
	setTimeout($force);
}

#
# Gibt die uebergebene Liste von Tracks aus
#
# Parameter:
#   1: Array von Hashes mit den Musiktiteln oder undef, falls die Seite nicht
#      erreichbar war.
# 
sub printResult($)
{
	my $tracks   = shift;
	my $first    = 1;
	my $maxwidth = 0;
	
	$textfeld->delete("1.0", 'end');
	
    # Die Seite war nicht erreichbar
	if (!$tracks) {
		$textfeld->configure(-height => $minZeilen);
		$textfeld->insert('end', "Sorry, konnte die sunshine-live Seite nicht erreichen.\n");
	}
    # Es waren keine Titel angegeben
	elsif (@$tracks == 0) {
		$textfeld->configure(-height => $minZeilen);
		$textfeld->insert('end', "Sorry, zum angegeben Zeitpunkt liegen keine Titel vor.\n");
	}
    # Gib die Titel aus
	else {
		my $zeilen = @$tracks + 1;
		$textfeld->configure(-height => ($zeilen > $minZeilen) ? $zeilen : $minZeilen);
		
		foreach my $track(@$tracks) {
			my $zeit	= '';
			my $line	= '';
			my $length	= 0;
			
			$zeit = $track->{'zeit'}.'   ';
			
            # Wenn der Dj oder Artist vor dem Titel ausgegeben werden soll
			if ($dj_titel) {
				$line = $track->{'artist'} .' - '. $track->{'titel'};
			}
			else {
				$line = $track->{'titel'} .' - '. $track->{'artist'};
			}
			
            # Errechne die maximal benoetigte Breite des Textfeldes
			$indent    = length($zeit);
			$length    = length($line) + $indent;
			($maxwidth = $length) if ($length > $maxwidth);

			$textfeld->insert('end', $zeit,
				($first && $aktuell) ? ['aktuell'] : ['normal']);

			$textfeld->insert('end', $line,
				($first && $aktuell) ? ['aktuell', 'track'] : ['normal', 'track'], "\n");

			$first = 0;
		}	
	}

	$textfeld->configure(-width => ($maxwidth > $minBreite) ? $maxwidth : $minBreite);
}

#
# Startet die Anwendung und den endlos Mainloop
#
sub startLoop()
{
	setTimeout(0);
    MainLoop();
}

sub printHelp()
{
    print "Usage $0: [hh:mm] [dd.mm[.yyyy]]\n";
}

sub main($)
{
	my $arg = shift;
	my @ARGV = @$arg;
	my ($datum, $sekunden, $uhrzeit, $stunde, $minute);
	
    # boolean, gibt an ob ein Benutzerdefiniertes Datum
    # verwendet wurde
    #
    # Wenn ein bestimmtes Datum angegeben wurde ist das
    # die letzte update Anzeige unnuetz. 
	my $datumAngegeben = 1;

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
    # Es wurde ein Datum angegeben
    else {
        $datumAngegeben = 0;
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

        # Es wurde eine Zeit angegeben
        $datumAngegeben = 0;
	}

	if ($DEBUG) 
	{
		Sunshine::setDebug($DEBUG);
	}

	# Minuten nur als vielfaches von 5
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

	setupWindow();

    #
    # Wenn ein bestimmtes Datum angegeben wurde ist das
    # die letzte update Anzeige unnuetz.
    #
	if (!$datumAngegeben) {
		$lastUpdate = '-';
	}
	else {
		my @current = localtime(time());
		$lastUpdate = sprintf("%02d:%02d", $current[2], $current[1]);
	}

	printResult(Sunshine::getPlaylistPage($stunde, $minute, $sekunden));
	startLoop();
}

main(\@ARGV);
