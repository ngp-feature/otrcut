#!/bin/bash

# Dieses Script schneidet Filme/Serien von http://www.onlinetvrecorder.de anhand der Schnittlisten von http://www.cutlist.at.
# Dies geschieht durch ffmpeg.
#
# Dieses Script darf frei verändert und weitergegeben werden.
#
# Original Author: Daniel Siegmanski

# Hier werden verschiedene Variablen definiert.
version=20251010	# Die Version von OtrCut, Format: yyyymmdd, yyyy=Jahr mm=Monat dd=Tag
LocalCutlistOkay=no	# Ist die lokale Cutlist vorhanden?
input=""			# Eingabedatei/en
LocalCutlistName=""	# Name der lokalen Cutlist
format=""			# Um welches Format handelt es sich? AVI, HQ, mp4
cutlistWithError=""	# Cutlists die, einen Fehler haben
delete=no
continue=0
rot="\033[22;31m"	# Rote Schrift
gruen="\033[22;32m"	# Grüne Schrift
gelb="\033[22;33m"	# Gelbe Schrift
blau="\033[22;34m"	# Blaue Schrift
normal="\033[0m"	# Normale Schrift

# Dieses Variablen werden gesetzt, sofern aber ein Config-File besteht wieder überschrieben
server="http://cutlist.at/"	# Cutlist URL
UseLocalCutlist=no	# Lokale Cutlists verwenden?
HaltByErrors=no		# Bei Fehlern anhalten?
toprated=no			# Die Cutlist mit der besten User-Bewertung benutzen?
ShowAllCutlists=yes	# Auswahl mehrerer Cutlists anzeigen?
tmp="/tmp/otrcut"	# Zu verwendender Tmp-Ordner, in diesem Ordner wird dann noch ein Ordner "otrcut" erstellt.
overwrite=no		# Bereits vorhandene Dateien überschreiben
output=cut			# Ausgabeordner
bewertung=no		# Bewertungsfunktion benutzen
verbose=yes			# Ausführliche Ausgabe von ffmpeg anzeigen
warn=yes			# Warnung bezüglich der Löschung von $tmp ausgeben
user=otrcut			# Benutzer der zum Bewerten benutzt wird
vcodec=copy			# Input-Video nur kopieren.
acodec=copy			# Input-Audio nur kopieren.
copy=no				# Wenn $toprated=yes, und keine Cutlist gefunden wird, $film nach $output kopieren
move=no				# Wenn $toprated=yes, und keine Cutlist gefunden wird, $film nach $output verschieben

# Diese Variablen werden vom Benutzer gesetzt.
# Sie sind für die Verwendung des Decoders gedacht.
email=""			# Die EMail-Adresse mit der Sie bei OTR registriert sind
password=""			# Das Passwort mit dem Sie sich bei OTR einloggen
decoder="otrdecoder" # Pfad zum decoder, z.B. /home/benutzer/bin/otrdecoder


scriptpath=$( realpath "$0" | sed 's|\(.*\)/.*|\1|' )


if [ -f ~/.otrcut ]; then
	source ~/.otrcut
elif [ -f "$scriptpath/otrcut.config" ]; then
	source "$scriptpath/otrcut.config"
else
	echo "Keine Config-Datei gefunden, benutze Standardwerte."
fi
	
# Diese Funktion gibt die Hilfe aus
function help ()
{
cat <<HELP
OtrCut Version: $version

Dieses Script schneidet Filme/Serien von http://www.onlinetvrecorder.de anhand der Schnittlisten von http://www.cutlist.at.
Zum Schneiden wird ffmpeg verwendet.

Hier die Anwendung:

$0 [optionen] -i film.mpg.avi

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
##################

HELP
exit 0
}


# Hier werden die übergebenen Option ausgewertet
while [ ! -z "$1" ]; do
	case $1 in
		-i | --input )		input="$2"; shift ;;
		-e | --error )		HaltByErrors=yes ;;
		-d | --decode )		decode=yes ;;
		--delete )			delete=yes ;;
		-l | --local )		UseLocalCutlist=yes ;;
		-t | --tmp )		tmp=$2; shift ;;
		-o | --output )		output=$2; shift ;;
		-ow | --overwrite )	overwrite=yes ;;
		-q | --quiet )		verbose=no ;;
		-b | --bewerten)	bewertung=yes ;;
		-w | --warn )		warn=no ;;
		-c | --copy )		copy=yes ;;
		-m | --move )		move=yes ;;
		--server )			server=$2; shift ;;
		--toprated )		toprated=yes ;;
		--vcodec )			vcodec="$2"; shift;;
		--acodec )			acodec="$2"; shift;;
		-h | --help )		help ;;
		--version )			echo "$version"; exit 0 ;;
	esac
	shift
done

server_name=$(echo "$server" | sed -E 's#^https?://([^/]+)/?.*#\1#')

# Diese Funktion gibt die Warnung bezüglich der Löschung von $tmp aus
function warnung ()
{
if [ "$warn" == "yes" ]; then
	if [ "$tmp" != "/tmp/otrcut" ]; then
		echo -e "${rot}"
		echo "ACHTUNG!!!"
		echo "Das Script wird alle Dateien in $tmp/otrcut löschen!"
		echo "Sie haben 5 Sekunden um das Script über \"a\" abzubrechen,"
		echo "oder über \"s\" zu überspringen."
		
		for (( I=5; I >= 1 ; I-- )); do
			echo -n "$I "
			sleep 1
			read -n 1 -s -t 1 EINGABEZEICHEN
			case "${EINGABEZEICHEN}" in
				"a" ) echo -e "${normal}"; exit 1;;
				"s" ) break;;
			esac
		done
		echo -e "${normal}"
		echo ""
		
	fi

	echo -e "${gelb}"
	echo "ACHTUNG!!!"
	echo "Die Eingabedateien müssen entweder ohne führende Verzeichnise "
	echo "(z.B. datei.avi, nur wenn Datei im aktuellen Verzeichnis!) oder"
	echo "mit dem KOMPLETTEN Pfad (z.B. /home/user/datei.avi) angegeben werden!"
	echo -e "${normal}"

	sleep 2
	echo ""
	
fi
}

# Diese Funktion überprüft verschiedene Einstellungen
function test ()
{
# Prüfen ob die Angabe einen absoluten Pfad hat
if echo $i | grep -v '^/' > /dev/null; then
	#Ist der Name ohne Pfadangabe?
	if echo $i | grep '/' > /dev/null; then
		# Pfad vorhanden - Fehler!
		echo -e "${rot}Relative Pfadangaben sind nicht zulässig!${normal}"
		exit 1
	fi
fi

# Hier wird überprüft ob eine Eingabedatei angegeben ist
if [ -z $i ]; then
	echo "${rot}Es wurde keine Eingabedatei angegeben!${normal}"
	exit 1
else
	# Überprüfe ob angegebene Datei existiert
	for f in $i; do
		if [ ! -f $f ]; then
			echo -e "${rot}Eingabedatei nicht gefunden!${normal}"
			exit 1
		fi
	done
fi

# Hier wird überprüft ob der Standard-Ausgabeordner verwendet werden soll.
# Wenn ja, wird überprüft ob er verfügbar ist, wenn nicht wird er erstellt.
# Wurde ein alternativer Ausgabeordner gewählt, wird geprüft ob er vorhanden ist.
# Ist er nicht vorhanden wird gefragt ob er erstellt werden soll.
if [ "$output" == "cut" ]; then
	if echo $i | grep -q .otrkey; then
		output="../$output"
	fi
	if [ ! -d "$output" ]; then
		if [ -w $PWD ]; then
			mkdir "$output"
			echo "Verwende $( realpath "$PWD/$output" ) als Ausgabeordner"
		else
			echo -e "${rot}Sie haben keine Schreibrechte für das Verzeichnis $( realpath "$PWD/$output" ).${normal}"
			exit 1
		fi
	fi
else
	if [ -d "$output" ] && [ -w "$output" ]; then
		echo "Verwende $output als Ausgabeordner."
	elif [ -d "$output" ] && [ ! -w "$output" ]; then
		echo -e "${rot}Sie haben keine Schreibrechte in $output.${normal}"
		exit 1
	else
		echo -e "${gelb}Das Verzeichnis $output wurde nicht gefunden, soll er erstellt werden? [y|n]${normal}"
		read OUTPUT
		while [ "$OUTPUT" == "" ] || [ ! "$OUTPUT" == "y" ] && [ ! "$OUTPUT" == "n" ]; do # Bei falscher Eingabe
			echo -e "${gelb}Falsche Eingabe, bitte nochmal:${normal}"
			read OUTPUT
		done
		if [ "$OUTPUT" == "n" ]; then # Wenn der Benutzer nein "sagt"
			echo "Ausgabeverzeichnis \"$output\" soll nicht erstellt werden."
			exit 1
		elif [ "$OUTPUT" == "y" ]; then # Wenn der Benutzer ja "sagt"
			echo -n "Erstelle Ordner $output -->"
			mkdir $output
			if [ -d "$output" ]; then
				echo -e "${gruen}okay${normal}"
			else
				echo -e "${rot}false${normal}"
				exit 1
			fi
		fi
	fi
fi

# Hier wird überprüft ob der Standard-Tmpordner verwendet werden soll.
# Wenn ja, wird überprüft ob er verfügbar ist, wenn nicht wird er erstellt.
# Wurde ein alternativer Tmpordner gewählt, wird geprüft ob er vorhanden ist.
# Ist er nicht vorhanden wird gefragt ob er erstellt werden soll.
if [ "$tmp" == "/tmp/otrcut" ]; then
	if [ ! -d "/tmp/otrcut" ]; then
		if [ -w /tmp ]; then
			mkdir "/tmp/otrcut"
			echo "Verwende $tmp als Ausgabeordner"
		else
			echo -e "${rot}Sie haben keine Schreibrechte in /tmp/ ${end}"
			exit 1
		fi
	fi
else
	if [ -d "$tmp" ] && [ -w "$tmp" ]; then
		mkdir "$tmp/otrcut"
		echo "Verwende $tmp/otrcut als Ausgabeordner."
		tmp="$tmp/otrcut"
	elif [ -d "$tmp" ] && [ ! -w "$tmp" ]; then
		echo -e "${rot}Sie haben keine Schreibrechte in $tmp!${end}"
	else
		echo -e "${gelb}$tmp wurde nicht gefunden, soll er erstellt werden? [y|n]${end}"
		read TMP # Lesen der Benutzereingabe nach $TMP
		while [ "$TMP" == "" ] || [ ! "$TMP" == "y" ] && [ ! "$TMP" == "n" ]; do # Bei falscher Eingabe	
			echo -e "${gelb}Falsche Eingabe, bitte nochmal:${end}" 
			read TMP # Lesen der Benutzereingabe nach $TMP
		done
		if [ $TMP == n ]; then # Wenn der Benutzer nein "sagt"
			echo "Tempverzeichnis \"$tmp\" soll nicht erstellt werden."
			exit 1
		elif [ $TMP == y ]; then # Wenn der Benutzer ja "sagt"
			echo -n "Erstelle Ordner $tmp --> "
			mkdir "$tmp/otrcut"
			if [ -d $tmp/otrcut ]; then
				echo -e "${gruen}okay${end}"
				tmp="$tmp/otrcut"
			else
				echo -e "${rot}false${end}"
				exit 1
			fi
		fi
	fi
fi
}

# Diese Funktion überprüft ob ffmpeg installiert ist
function software ()
{
echo -n "Überprüfe ob ffmpeg installiert ist --> "
if type -t ffmpeg >> /dev/null; then
	echo -e "${gruen}okay${normal}"
	CutProg="ffmpeg"
else
	echo -e "${rot}false${normal}"
fi
if [ -z $CutProg ]; then
	echo -e "${rot}Bitte installieren sie ffmpeg${normal}"
	exit 1
fi

# Hier wird überprüft ob der richtige Pfad zum Decoder angegeben wurde
if [ "$decoded" == "yes" ]; then
	echo -n "Überprüfe ob der Decoder-Pfad richtig gesetzt wurde --> "
	if $decoder -v >> /dev/null; then
		echo -e "${gruen}okay${normal}"
	else
		echo -e "${rot}false${normal}"
		exit 1
	fi
	if [ "$email" == "" ]; then
		echo -e "${rot}E-Mail-Adresse wurde nicht gesetzt.${normal}"
		exit 1
	fi
	if [ "$password" == "" ]; then
		echo -e "${rot}Passwort wurde nicht gesetzt.${normal}"
		exit 1
	fi
fi
}

# Diese Funktion definiert den Cutlist- und Dateinamen und üperprüft um welches Dateiformat es sich handelt
function name ()
{
film=$i # Der komplette Filmname und gegebenfalls der Pfad
film_ohne_anfang=$i
film_ohne_anfang=${film_ohne_anfang%%.otrkey}
film_ohne_anfang=${film_ohne_anfang##*/}
film=$film_ohne_anfang

echo -n "Überprüfe um welches Aufnahmeformat es sich handelt --> "
if echo "$film_ohne_anfang" | grep -q ".HQ.avi"; then # Wenn es sich um eine "HQ" Aufnahme handelt
	film_ohne_ende=${film%%.mpg.HQ.avi} # Filmname ohne Dateiendung
	format=hq
	echo -e "${blau}HQ${normal}"
elif echo "$film_ohne_anfang" | grep -q ".mp4"; then # Wenn es sich um eine "mp4" Aufnahme handelt
	film_ohne_ende=${film%%.mpg.mp4} # Filmname ohne Dateiendung
	format=mp4
	echo -e "${blau}mp4${normal}"
elif echo "$film_ohne_anfang" | grep -q ".HD.avi"; then # Wenn es sich um eine "HD" Aufnahme handelt
	film_ohne_ende=${film%%.mpg.HD.avi} # Filmename ohne Dateiendung
	format=hd
	echo -e "${blau}HD${normal}"
elif echo "$film_ohne_anfang" | grep -q ".HD.mkv"; then # Wenn es sich um eine "MKV" Aufnahme handelt
	film_ohne_ende=${film%%.mpg.HD.mkv} # Filmname ohne Dateiendung
	format=mkv
	echo -e "${blau}mkv${normal}"
elif echo "$film_ohne_anfang" | grep -q ".mpg.avi"; then # Wenn es sich um eine "AVI" Aufnahme handelt
	film_ohne_ende=${film%%.mpg.avi} # Filmname ohne Dateiendung
	format=avi
	echo -e "${blau}avi${normal}"
fi

outputfile=""
if echo "$film_ohne_anfang" | grep -q ".HQ.avi"; then
	outputfile=$( realpath "$output/$film_ohne_ende-cut.HQ.avi" )
elif echo "$film_ohne_anfang" | grep -q ".mp4"; then
	outputfile=$( realpath "$output/$film_ohne_ende-cut.mp4" )
elif echo "$film_ohne_anfang" | grep -q ".HD.avi"; then
	outputfile=$( realpath "$output/$film_ohne_ende-cut.HD.avi" )
elif echo "$film_ohne_anfang" | grep -q ".HD.mkv"; then
	outputfile=$( realpath "$output/$film_ohne_ende-cut.HD.mkv" )
elif echo "$film_ohne_anfang" | grep -q ".mpg.avi"; then
	outputfile=$( realpath "$output/$film_ohne_ende-cut.avi" )
fi

if [ "$outputfile" == "" ]; then
	echo -e "${rot}Aufnahmeformat nicht definiert.${normal}"
	exit 1
fi


search_name=${film##*/}
search_name=${search_name%%TVOON*}

echo $search_name
echo $film_ohne_ende
echo $film_ohne_anfang

film_file=$film

}

# In dieser Funktion wir die lokale Cutlist überprüft
function local ()
{
local_cutlists=$(ls *.cutlist) # Variable mit allen Cutlists in $PWD
filesize=$(ls -l $film | awk '{ print $5 }') # Dateigröße des Filmes
let goodCount=0 # Passende Cutlists
let arraylocal=1 # Nummer des Arrays
for f in $local_cutlists; do
	echo -n "Überprüfe ob eine der gefundenen Cutlists zum Film passt --> "
	if [ -z $f ]; then
		echo -e "${rot}Keine Cutlist gefunden!${normal}"
		if [ "$HaltByErrors" == "yes" ]; then
			exit 1
		else
			vorhanden=no
			continue=1
		fi
	fi

	OriginalFileSize=$(cat $f | grep OriginalFileSizeBytes | cut -d"=" -f2 | tr -d "\r") # Dateigröße des Films
	
	apply_grep=${film%.mpg*}
	if cat $f | grep -q "$apply_grep"; then # Wenn der Dateiname mit ApplyToFile übereinstimmt
		echo -e -n "${blau}ApplyToFile ${normal}"
		ApplyToFile=yes	
		vorhanden=yes
	fi
	if [ "$OriginalFileSize" == "$filesize" ]; then # Wenn die Dateigröße mit OriginalFileSizeBytes übereinstimmt
		echo -e -n "${blau}OriginalFileSizeBytes${normal}"
		OriginalFileSizeBytes=yes 
		vorhanden=yes
	fi
	if [ "$vorhanden" == "yes" ]; then # Wenn eine passende Cutlist vorhanden ist
		let goodCount++
		namelocal[$arraylocal]="$f"
		#echo $f
		#echo ${namelocal[$arrylocal]}
		let arraylocal++
		continue=0
		echo ""
	else
		echo -e "${rot}false${normal}"
	fi		
done

if [ "$goodCount" -eq 1 ]; then # Wenn nur eine Cutlist gefunden wurde
	echo "Es wurde eine passende Cutlist gefunden. Diese wird nun verwendet."
	CUTLIST="$f"
	cp $CUTLIST $tmp
elif [ "$goodCount" -gt 1 ]; then # Wenn mehrere Cutlists gefunden wurden
	echo "Es wurden $goodCount Cutlists gefunden. Bitte wählen Sie aus:"
	echo ""
	let number=1
	for (( i=1; i <= $goodCount ; i++ )); do
		echo "$number: ${namelocal[$number]}"
		let number++
	done
	echo -n "Bitte die Nummer der zu verwendenden Cutlist eingeben:"
	read NUMBER
	while [ "$NUMBER" -gt "$goodCount" ]; do
		echo "${rot}false. Noch mal:${normal}"
		read NUMBER
	done
	echo "Verwende ${namelocal[$NUMBER]} als Cutlist."
	CUTLIST=${namelocal[$NUMBER]}
	cp $CUTLIST $tmp
	vorhanden=yes
else
	exit 1
fi
}

# In dieser Funktion wird versucht eine Cutlist aus den Internet zu laden
function load ()
{
# In dieser Funktion wird geprüft, ob die Cutlist okay ist
function test_cutlist ()
{
let cutlist_size=$(ls -l $tmp/$CUTLIST | awk '{ print $5 }')
if [ "$cutlist_size" -lt "100" ]; then
	cutlist_okay=no
	rm -rf $TMP/$CUTLIST
else
	cutlist_okay=yes
fi
}

echo -e "Bearbeite folgende Datei: ${blau}$film${normal}"
sleep 1

echo -n "Führe Suchanfrage bei $server_name durch ---> "

wget -q -O $tmp/search.xml "${server}getxml.php?version=0.9.8&name=$search_name"

if grep -q '<id>' "$tmp/search.xml"; then
	echo -e "${gruen}okay${normal}"
else
	echo -e "${rot}false${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	else
		continue=1
	fi
fi

# Hier wird die Suchanfrage überprüft
if [ "$continue" == "1" ]; then
	echo -e "${rot}Es wurden keine Cutlists auf $server_name gefunden.${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	elif [ "$toprated" == "no" ] && [ "$copy" == "no" ] && [ "$move" == "no" ]; then
		continue=1
		echo -e "${blau}Soll \"$film\" in den Ausgabeordner kopiert erden? [y|n]${normal}"
		read COPY
		while [ "$COPY" == "" ] || [ ! "$COPY" == "y" ] && [ ! "$COPY" == "n" ]; do # Bei falscher Eingabe
			echo -e "${gelb}Falsche Eingabe, bitte nochmal:${normal}"
			read COPY
		done
		if [ "$COPY" == "n" ]; then # Wenn der Benutzer nein "sagt"
			echo "Datei wird nicht kopiert."
		elif [ "$COPY" == "y" ]; then # Wenn der Benutzer ja "sagt"
			echo "Datei wird in den Ausgabeordner kopiert."
			cp $tmp/$film $output/
		fi
	elif [ "$copy" == "yes" ]; then
		echo "Datei wird in den Ausgabeordner kopiert."
		cp $tmp/$film $output/
	elif [ "$move" == "yes" ]; then
		echo "Datei wird in den Ausgabeordner verschoben."
		mv $tmp/$film $output/
	fi
else
	if [ "$schon_mal_angezeigt" == "" ]; then
		echo -e "${blau}Cutlist/s gefunden.${normal}"
		echo ""
		echo "Es wurden folgende Cutlists gefunden:"
		schon_mal_angezeigt=yes
		let array=0
	fi
	cutlist_anzahl=$(grep -c '/cutlist' "$tmp/search.xml" | tr -d "\r") # Anzahl der gefundenen Cutlists
	let cutlist_anzahl
	if [ "$cutlist_anzahl" -ge "1" ] && [ "$continue" == "0" ]; then # Wenn mehrere Cutlists gefunden wurden
		echo ""
		let tail=1
		while [ "$cutlist_anzahl" -gt "0" ]; do
			# Name der Cutlist
			name[$array]=$(grep "<name>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Author der Cutlist
			author[$array]=$(grep "<author>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Bewertung des Authors
			ratingbyauthor[$array]=$(grep "<ratingbyauthor>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Bewertung der User
			rating[$array]=$(grep "<rating>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Kommentar des Authors
			comment[$array]=$(grep "<usercomment>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# ID der Cutlist
			ID[$array]=$(grep "<id>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Anzahl der Bewertungen
			ratingcount[$array]=$(grep "<ratingcount>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Cutangaben in Sekunden
			cutinseconds[$array]=$(grep "<withtime>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Cutangaben in Frames (besser)
			cutinframes[$array]=$(grep "<withframes>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")
			# Filename der Cutlist
			filename[$array]=$(grep "<filename>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | tail -n$tail | head -n1 | tr -d "\r")

			if [ "$toprated" == "no" ]; then # Wenn --toprated nicht gesetzt ist
				if echo $cutlistWithError | grep -q "${ID[$array]}"; then # Wenn Fehler gesetzt ist z.B. EPG-Error oder MissingBeginning
					echo -ne "${rot}"
				fi
				echo -n "[$array]"
				echo "  Name: ${name[$array]}"
				echo "     Author: ${author[$array]}"
				echo "     Rating by Author: ${ratingbyauthor[$array]}"
				if [ -z "$cutlistWithError" ]; then
					echo -ne "${gruen}"
				fi
				echo "     Rating by Users: ${rating[$array]} @ ${ratingcount[$array]} Users"
				if [ -z "$cutlistWithError" ]; then
					echo -ne "${normal}"
				fi
				if [ "${cutinframes[$array]}" == "1" ]; then
					echo "     Cutangabe: Als Frames"
				fi
				if [ "${cutinseconds[$array]}" == "1" ] && [ ! "${cutinframes[$array]}" == "1" ]; then
					echo "     Cutangabe: Als Zeit"
				fi
				echo "     Kommentar: ${comment[$array]}"
				echo "     Filename: ${filename[$array]}"
				echo "     ID: ${ID[$array]}"
				#echo "     Server: ${server[$array]}"
				echo ""
				if echo $cutlistWithError | grep -q "${ID[$array]}"; then # Wenn Fehler gesetzt ist z.B. EPG-Error oder MissingBeginning
					echo -ne "${normal}"
				fi
			fi
			
			let tail++
			let cutlist_anzahl--
			let array++
			array1=array
		done

		if [ "$toprated" == "yes" ]; then # Wenn --toprated gesetzt wurde
			if [ "$angezeigt" == "" ]; then
				echo "Lade die Cutlist mit der besten User-Bewertung herunter."
				angezeigt=yes
			fi
			let array1--
			while [ $array1 -ge 0 ]; do
				rating1[$array1]=${rating[$array1]}	
				if [ "${rating1[$array1]}" == "" ]; then # Wenn keine Benutzerwertung abgegeben wurde
					rating1[$array1]="0.00" # Schreibe 0.00 als Bewertung
				fi
				
				rating1[$array1]=$(echo ${rating1[$array1]} | sed 's/\.//g') # Entferne den Dezimalpunkt aus der Bewertung. 4.50 wird zu 450
				#echo "Rating ohne Komma: ${rating1[$array1]}"
				let array1--
			done
			numvalues=${#rating1[@]} # Anzahl der Arrays
			for (( i=0; i < numvalues; i++ )); do
				lowest=$i
				for (( j=i; j < numvalues; j++ )); do
					if [ ${rating1[j]} -ge ${rating1[$lowest]} ]; then
						lowest=$j
					fi
				done
				
				temp=${rating1[i]}
				rating1[i]=${rating1[lowest]}
				rating1[lowest]=$temp
			done
			bigest=${rating1[0]}
			
			beste_bewertung=${bigest%%??} # Die beste Wertung ohne Dezimalpunkt
			beste_bewertung_punkt=$beste_bewertung.${bigest##?}	# Die beste Wertung mit Dezimalpunkt
			unset rating1
			unset cutlist_anzahl
			unset array
		fi
	fi
fi

if [ "$toprated" == "yes" ] && [ "$continue" == "0" ]; then
	bereits_toprated=no
	echo "Die beste Bewertung ist: $beste_bewertung"
	bereits_toprated=yes	
	
	if [ "$beste_bewertung" == "0" ]; then
		beste_bewertung="</rating>"
	fi

	cutlist_nummer=$(grep "<rating>" "$tmp/search.xml" | grep -n "<rating>$beste_bewertung" | cut -d: -f1 | head -n1)

	if [ -z  $cutlist_nummer ]; then
		beste_bewertung="0.00"
		cutlist_nummer=$(grep "<rating>" "$tmp/search.xml" | grep -n "<rating>$beste_bewertung" | cut -d: -f1 | head -n1)
	fi
	id=$(grep "<id>" "$tmp/search.xml" | head -n$cutlist_nummer | tail -n1 | cut -d">" -f2 | cut -d"<" -f1) # ID der best bewertetsten Cutlist
	let num=$cutlist_nummer-1
	id_downloaded=$(echo ${ID[$num]})
	CUTLIST=$(grep "<name>" "$tmp/search.xml" | cut -d">" -f2 | cut -d"<" -f1 | head -n$cutlist_nummer | tail -n1 | tr -d "\r") # Name der Cutlist
	beste_bewertung="0"
fi

if [ "$toprated" == "no" ] && [ "$continue" == "0" ]; then
	let array_groesse=$array
	let array_groesse--
	CUTLIST_ZAHL=""
	while [ "$CUTLIST_ZAHL" == "" ]; do # Wenn noch keine Cutlist gewählt wurde
		echo -n "Bitte die Nummer der zu verwendenden Cutlist eingeben: "
		read CUTLIST_ZAHL # Benutzereingabe lesen
		if [ -z "$CUTLIST_ZAHL" ]; then
			echo -e "${gelb}Ungültige Auswahl.${normal}"
			CUTLIST_ZAHL=""
		elif [ "$CUTLIST_ZAHL" -gt "$array_groesse" ]; then
			echo -e "${gelb}Ungültige Auswahl.${normal}"
			CUTLIST_ZAHL=""
		fi
	done
	let array_groesse=$CUTLIST_ZAHL
	let CUTLIST_ZAHL++
	id=$(grep "<id>" "$tmp/search.xml" | tail -n$CUTLIST_ZAHL | head -n1 | cut -d">" -f2 | cut -d"<" -f1)
	let num=$CUTLIST_ZAHL-1
	id_downloaded=$(echo ${id[$num]})
	CUTLIST=$(grep "<name>" "$tmp/search.xml" | tail -n$CUTLIST_ZAHL | head -n1 | cut -d">" -f2 | cut -d"<" -f1)
fi

if [ "$continue" == "0" ]; then
	echo -n "Lade $CUTLIST -->"
	
	wget -q -O $tmp/$CUTLIST "${server}getfile.php?id=$id"
	test_cutlist # Testen der Cutlist
	if [ -f "$tmp/$CUTLIST" ] && [ "$cutlist_okay" == "yes" ]; then
		echo -e "${gruen}okay${normal}"
		continue=0
	else	
		echo -e "${rot}false${normal}"
		if [ "$HaltByErrors" == "yes" ]; then
			exit 1
		else
			continue=1
		fi
	fi
fi
}


# Hier wird überprüft um welches Cutlist-Format es sich handelt
function format ()
{
echo -n "Überprüfe um welches Format es sich handelt --> "
if cat $tmp/$CUTLIST | grep "StartFrame=" >> /dev/null; then
	echo -e "${blau}Frames${normal}"
	format=frames
elif cat $tmp/$CUTLIST | grep "Start=" >> /dev/null; then
	echo -e "${blau}Zeit${normal}"
	format=zeit
else
	echo -e "${rot}false${normal}"
	echo -e "${rot}Wahrscheinlich wurde das Limit deines Cutlist-Anbieters erreicht!${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	else
		continue=1
	fi
fi
}

# Hier werden die Bilder Pro Sekunde ermittelt (Wichtig für US-Aufnahmen)
function which_fps ()
{

echo -n "Bilder Pro Sekunde --> "

fps=$(
	if type -t ffprobe >> /dev/null; then
		ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate $film_file
	else
		ffmpeg -hide_banner -i $film_file 2>&1 | sed -n "s/.*Video.*, \(.*\) fp.*/\1/p"
	fi
)

if [ $(echo "$fps" | bc -l ) ]; then
	echo -e "${blau}$(echo "scale=3; $fps" | bc -l )${normal}"
else
	echo -e "${rot}Es muss ein Fehler aufgetreten sein!${normal}"
	if [ "$HaltByErrors" == "yes" ]; then
		exit 1
	else
		continue=1
	fi
fi
}

# Hier wir die Cutlist überprüft, auf z.B. EPGErrors, MissingEnding, MissingVideo, ...
function cutlist_error ()
{
# Diese Variable beinhaltet alle möglichen Fehler
errors="EPGError MissingBeginning MissingEnding MissingVideo MissingAudio OtherError"
for e in $errors; do
	error_check=$(cat $tmp/$CUTLIST | grep -m1 $e | cut -d"=" -f2 | tr -d "\r")
	if [ "$error_check" == "1" ]; then
		echo -e "${rot}Es wurde ein Fehler gefunden: \"$e\"${normal}"
		error_yes=$e
		if [ "$error_yes" == "OtherError" ]; then
			othererror=$(cat $tmp/$CUTLIST | grep "OtherErrorDescription")
			othererror=${othererror##*=}
			echo -e "${rot}Grund für \"OtherError\": \"$othererror\"${normal}"
		fi
		if [ "$error_yes" == "EPGError" ]; then
			epgerror=$(cat $tmp/$CUTLIST | grep "ActualContent")
			epgerror=${epgerror##*=}
			echo -e "${rot}ActualContent: $epgerror${end}"
		fi
		error_found=1
		cutlistWithError="${cutlistWithError} $id_downloaded"
		#echo $cutlistWithError
	fi
done
}


# Hier wird nun ffmpeg gestartet
function demux ()
{

loglevel=""
if [ $verbose == "yes" ]; then
	loglevel=" -loglevel error"
fi

cut_anzahl=$(( $(grep "NoOfCuts" "$tmp/$CUTLIST" | cut -d"=" -f2 | tr -d "\r") ))
echo "##### Anwendung der Cuts #####"

if [ "$format" = "zeit" ]; then
	let head2=1
	echo "Es müssen $cut_anzahl Cuts umgerechnet werden"
	while [ "$cut_anzahl" -gt 0 ]; do
		let time_seconds_start=$(cat $tmp/$CUTLIST | grep "Start=" | cut -d= -f2 | head -n$head2 | tail -n1 | cut -d"." -f1 | tr -d "\r")
		echo "Startzeit: $time_seconds_start"
		
		let time_seconds_dauer=$(cat  $tmp/$CUTLIST | grep "Duration=" | cut -d= -f2 | head -n$head2 | tail -n1 | cut -d"." -f1 | tr -d "\r")
		
		echo "Dauer: $time_seconds_dauer"
		
		SEGFILE="$tmp/part_${head2}.${film##*.}"
		call="ffmpeg -hide_banner$loglevel -accurate_seek -i \"$film_file\" -ss \"$time_seconds_start\" -t \"$time_seconds_dauer\" -c:v $vcodec -c:a $acodec -avoid_negative_ts 1 \"$SEGFILE\""
		echo $call
		eval "$call"
		
		echo "file '$SEGFILE'" >> "$tmp/list.txt"
		let head2++
		let cut_anzahl--
	done
	
elif [ "$format" = "frames" ]; then
	let head2=1
	echo "Es müssen $cut_anzahl Cuts umgerechnet werden"
	while [ $cut_anzahl -gt 0 ]; do
		let startframe=$(cat $tmp/$CUTLIST | grep "StartFrame=" | cut -d= -f2 | head -n$head2 | tail -n1 | tr -d "\r")
		echo "Startframe: $startframe"
		
		let dauerframe=$(cat $tmp/$CUTLIST | grep "DurationFrames=" | cut -d= -f2 | head -n$head2 | tail -n1 | tr -d "\r")
		time_seconds_start=$(echo "scale=3; $startframe / $fps" | bc -l )
		time_seconds_dauer=$(echo "scale=3; $dauerframe / $fps" | bc -l )
		
		echo "Dauer: $dauerframe"
		
		SEGFILE="$tmp/part_${head2}.${film##*.}"
		call="ffmpeg -hide_banner$loglevel -accurate_seek -i \"$film_file\" -ss \"$time_seconds_start\" -t \"$time_seconds_dauer\" -c:v $vcodec -c:a $acodec -avoid_negative_ts 1 \"$SEGFILE\""
		echo $call
		eval "$call"
		
		echo "file '$SEGFILE'" >> "$tmp/list.txt"
		let head2++
		let cut_anzahl--
	done
fi

echo "##### Fertig #####"
sleep 1


echo "Übergebe die Cuts nun an ffmpeg"

ffmpeg -y -hide_banner$loglevel -f concat -safe 0 -i "$tmp/list.txt" -c copy "$outputfile"


if [ -f "$outputfile" ] && [ $(ls -l $outputfile | awk '{ print $5 }' | bc -l) -gt 10485760 ]; then
	echo -n -e  ${gruen}$outputfile${normal}
		echo -e "${gruen} wurde erstellt${normal}"
	if [ "$delete" == "yes" ]; then
		echo "Lösche Quellvideo."
		if [ $decoded == "yes" ]; then
			rm -rf $tmp/$film
		else
			rm -rf $film
		fi
	fi
	del_tmp
else
	echo -e "${rot}Irgendwas ist schiefgelaufen${normal}"
	if [ $HaltByErrors == "yes" ]; then
		exit 1
	else
		continue=1
	fi
fi
}

# Hier wird nun, wenn gewünscht, eine Bewertung für die Cutlist abgegeben
function bewertung ()
{
echo ""
echo "Sie können nun eine Bewertung für die Cutlist abgeben."
echo "Folgende Noten stehen zur verfügung:"
echo "[0] Test (schlechteste Wertung)"
echo "[1] Anfang und Ende geschnitten"
echo "[2] +/- 5 Sekunden"
echo "[3] +/- 1 Sekunde"
echo "[4] Framegenau"
echo "[5] Framegenau und keine doppelten Szenen"
echo ""
echo "Sollten Sie für diese Cutlist keine Bewertung abgeben wollen,"
echo "drücken Sie einfach ENTER."
echo -n "Note: "
note=""
read note
while [ ! "$note" == "" ] && [ "$note" -gt "5" ]; do
	note=""
	echo -e "${gelb}Ungültige Eingabe, bitte nochmal:${normal}"
	read note
done
if [ "$note" == "" ]; then
	echo "Für diese Cutlist wird keine Bewertung abgegeben."
else
	echo -n "Übermittle Bewertung für $CUTLIST -->"
	
	wget -q -O $tmp/rate.php "{$server}rate.php?rate=$id&rating=$note&userid=$user&version=0.9.8.7"
	
	sleep 1
	if [ -f "$tmp/rate.php" ]; then
		if cat "$tmp/rate.php" | grep -q "Cutlist nicht von hier. Bewertung abgelehnt."; then
			echo -e " ${rot}False${normal}"	
			echo -e " ${rot}Die Cutlist ist nicht von $server_name und kann nicht bewertet werden.${normal}"
		elif cat "$tmp/rate.php" | grep -q "Du hast schon eine Bewertung abgegeben oder Cutlist selbst hochgeladen."; then
			echo -e " ${rot}False${normal}"
			echo -e "${rot}Du hast für die Cutlist schonmal eine Bewertung abgegeben oder sie selbst hochgeladen.${normal}"
		elif cat "$tmp/rate.php" | grep -q "Sie haben diese Liste bereits bewertet"; then
			echo -e " ${rot}False${normal}"
			echo -e "${rot}Du hast für die Cutlist schonmal eine Bewertung abgegeben oder sie selbst hochgeladen.${normal}"
		elif cat "$tmp/rate.php" | grep -q "Cutlist wurde bewertet"; then
			echo -e "${gruen}Okay${normal}"
			echo -e "${gruen}Cutlist wurde bewertet${normal}"
		fi
	else
		echo -e "${rot}False${normal}"
		echo -e "${rot}Bewertung fehlgeschlagen.${normal}"
	fi
fi
}

# Hier wird ein Otrkey-File dekodiert, falls es gewünscht ist
function decode ()
{
if echo $i | grep -q .otrkey; then
	if [ ! "$email_checked" == "yes" ]; then
		if [ "$email" == "" ]; then
			echo -e "${rot}Kann nicht dekodieren da keine E-Mail-Adresse angegeben wurde!${normal}"
			exit 1
		elif [ "$password" == "" ]; then
			echo -e "${rot}Kann nicht dekodieren da kein Passwort angegeben wurde!${normal}"
			exit 1
		else
			email_checked=yes
		fi
	fi
	echo "Decodiere Datei --> "
	$decoder -e $email -p $password -q -f -i $i -o "$tmp"
	otrkey=$i
	decoded=yes
	
	film_file=$tmp/$film_ohne_anfang
	
	if [ ! -f "$tmp/$film_ohne_anfang" ]; then
		echo -e "${rot}Die Datei konnte nicht dekodiert werden!${normal}"
		exit 1
	fi
else
	decoded=no
fi
if [ "$delete" == "yes" ]; then
	echo "Lösche OtrKey"
	rm -rf $otrkey
fi
}

# Hier werden nun die temporären Dateien gelöscht
function del_tmp ()
{
if [ "$tmp" == "" ] || [ "$tmp" == "/" ] || [ "$tmp" == "/home" ]; then
	echo -e "${rot}Achtung, bitte überprüfen Sie die Einstellung von \$tmp${normal}"
	exit 1
fi
echo "Lösche temporäre Dateien"
#echo $tmp
rm -rf $tmp/*
}


if [ "$warn" == "yes" ]; then
	warnung
fi

software
	for i in $input; do
		test
		del_tmp
		name
		decode
		which_fps
		if [ "$UseLocalCutlist" == "yes" ]; then
			local
		fi
		while true; do
			if [ "$UseLocalCutlist" == "no" ] || [ "$vorhanden" == "no" ] && [ "$continue" == "0" ]; then
				load
			fi
			if [ "$continue" == "0" ]; then
				format
			fi
			if [ "$continue" == "0" ]; then
				cutlist_error
			fi
			if [ "$error_found" == "1" ] && [ "$toprated" == "no" ]; then
				echo -e "${gelb}In der Cutlist wurde ein Fehler gefunden, soll sie verwendet werden? [y|n]${normal}"
				read error_antwort
				if [ "$error_antwort" == "y" ] || [ "$error_antwort" == "j" ]; then
					echo -e "${gelb}Verwende die Cutlist trotz Fehler!${normal}"
					break
				else
					echo "Bitte neue Cutlist wählen!"
				fi
			else
				break
			fi
			if [ "$error_found" == "1" ] && [ "$toprated" == "yes" ]; then
				break
			fi
		done
		
		if [ "$CutProg" = "ffmpeg" ] && [ $continue == "0" ]; then
			if [ "$overwrite" == "no" ]; then
				if [ ! -f "$outputfile" ]; then
					demux
				else
					echo -e "${gelb}Die Ausgabedatei existiert bereits, soll sie überschrieben werden? [y|n]${normal}"
					read overwrite_antwort
					if [ "$overwrite_antwort" == "y" ] || [ "$overwrite_antwort" == "j" ]; then
						demux
					elif [ $HaltByErrors == "yes" ]; then
						exit 1
					else
						continue=1
					fi
				fi
			fi
			if [ "$overwrite" == "yes" ]; then
				demux
			fi
		fi
	if [ "$decoded" == "yes" ]; then
		rm -rf "$tmp/$film"
	fi
	
	continue=0
done

echo -e "${normal}"
echo ""
