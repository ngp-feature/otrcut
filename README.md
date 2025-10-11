# otrcut
Dieses Script schneidet Filme/Serien von http://www.onlinetvrecorder.de anhand der Schnittlisten von http://www.cutlist.at.
Zum Schneiden wird ffmpeg verwendet.


Dieses Script darf frei verändert und weitergegeben werden.

otrcut.sh [optionen] -i film.HQ.avi

otrcut.sh [optionen] -i film.HQ.avi.otrkey

Optionen:

-i, --input [arg]	Input Datei/Dateien

-e, --error		Bei Fehlern das Script beenden

--tmp [arg]		TMP-Ordner angeben (Standard: /tmp/), In diesem Ordner wird noch ein Ordner "otrcut" angelegt, ACHTUNG: ALLE Daten in \$tmp werden gelöscht!!!

-l, --local 		Lokale Cutlists verwenden (Cutlists werden im aktuellen Verzeichnis gesucht) (nicht getestet)

--delete		Quellvideo nach Schneidevorgang löschen ACHTUNG: Falls es sich bei der Quelle um ein OtrKey handelt wird dies auch gelöscht!!!

-o, --output [arg]	Ausgabeordner wählen (Standard "./cut")

-ow, --overwrite	Schon existierende Ausgabedateien überschreiben

-b, --bewertung		Bewertungsfunktion aktivieren (nicht getestet)

-w, --warn		Verschiedenen Warnungen werden nicht angezeigt.

--toprated		Verwendet die best bewertetste Cutlist (nicht getestet)

-q, --quiet		Ausgaben von ffmpeg deaktivieren

-c, --copy		Wenn \$toprated=yes, und keine Cutlist gefunden wird, \$film nach \$output kopieren

-m, --move		Wenn \$toprated=yes, und keine Cutlist gefunden wird, \$film nach \$output verschieben

--server		URL des Cutlist-Servers. Standard ist http://cutlist.at/

--vcodec [arg]		Videocodec für ffmpeg spezifizieren. Wenn nicht gesetzt, dann "copy".

--acodec [arg]		Audiocodec für ffmpeg spezifizieren. Wenn nicht gesetzt, dann "copy".

-h, --help		Diese Hilfe ^^

###  Original  ### 
	Author: Daniel Siegmanski
	
	Danke an MKay für das Aspect-Ratio-Script.
	Danke an Florian Knodt für seinen Patch.

