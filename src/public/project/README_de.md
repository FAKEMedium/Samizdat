[description]: # "Samizdat ist ein neuer Ansatz für Selbstverlag, der moderne Technologie nutzt."
[keywords]: # "Verlagswesen,Samizdat"

# Samizdat-Projekt

Im ehemaligen Ostblock, wo die freie Meinungsäußerung verboten war, nutzten die Menschen andere Methoden. Die Untergrund-Graswurzelbewegung der manuellen Reproduktion und Verbreitung von Texten wurde Samizdat genannt.

* Erfahren Sie mehr über [Nutzung und Installation](installation/)
* Wie Sie [beitragen](../contribute/) können

### Highlights

* Internationalisierungsunterstützung
* Menschenlesbare Formate &mdash; YAML und Markdown
* Geschwindigkeitsoptimierung &mdash; automatische WebP-Bilder, intelligentes Caching von generiertem Inhalt, Minimierung
* Hübsch formatiertes und semantisches HTML5
* Intelligente Mojolicious-Templates
* Automatische ein- oder zweispaltige Layouts mit verketteten Seitenpanels
* Hilfsfunktion für [einfaches Einbinden von SVG-Bildern](./icons/)
* Hilfsfunktion für [Länderdaten](../../country/)

### Verzeichnisstruktur

* bin - Skripte
* lib - Perl-Module
  * Samizdat
    * Command - Perl-Module, die Optionen zum Samizdat-Befehl hinzufügen.
* public - Statische Dateien. Markdown. Verarbeitete Dateien werden auch hier als zwischengespeicherte Inhalte abgelegt.
* t - Testsuite
* templates - Vorlagen, Layouts und kleinere Bausteine

Die Dateien im public-Verzeichnis sind diejenigen, die in das Disk-Image (ISO-Format) für die lokale Anzeige aufgenommen werden. 
Es ist auch möglich, einen Webserver zu verwenden und blitzschnelle Inhalte zu servieren. Hoffentlich finde ich auch eine Bittorrent-Lösung, 
um Videos zu streamen. Fakenews.com wird Samizdat für eine gewisse Zeit nutzen und regelmäßige Updates anbieten.

### Persönliche Nutzung Piraterie

Dem Repository sollte kein Medienmaterial hinzugefügt werden. Betrachten Sie den Code als ein Werkzeug, um einige Ihrer Lieblingsinhalte 
mitzunehmen, wenn Sie Zeit auf einer isolierten Insel verbringen.