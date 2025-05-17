# Samizdat-projektet

I det forna östblocket där yttrandefrihet var förbjuden använde människor andra metoder. Den underjordiska gräsrotsrörelsen för manuell reproduktion och distribution av text kallades samizdat.

* Lär dig om [användning och installation](installation/)
* Hur du kan [bidra](../contribute/)

### Höjdpunkter

* Stöd för internationalisering
* Mänskligt läsbara format &mdash; YAML och Markdown
* Hastighetsoptimering &mdash; automatiska WebP-bilder, smart cachning av genererat innehåll, minimering
* Snyggt formaterad och semantisk HTML5
* Smarta Mojolicious-mallar
* Automatiska layouter med en eller två kolumner med sammansatta sidopaneler
* Hjälpfunktion för [enkel inbäddning av SVG-bilder](./icons/)
* Hjälpfunktion för [landsdata](../../country/)

### Katalogstruktur

* bin - Skript
* lib - Perl-moduler
  * Samizdat
    * Command - Perl-moduler som lägger till alternativ till samizdat-kommandot.
* public - Statiska filer. Markdown. Bearbetade filer hamnar också här som cachat innehåll.
* t - Testsvit
* templates - Mallar, layouter och mindre delar

Filerna i public-katalogen är de som går in i skivavbildningen (ISO-format) för att visas lokalt. 
Det är också möjligt att använda en webbserver och servera blixtsnabbt innehåll. Förhoppningsvis hittar 
jag också en Bittorrent-lösning för att strömma video. Fakenews.com kommer att använda Samizdat under 
en period och ha regelbundna uppdateringar.

### Personlig användning piratkopiering

Inget mediematerial bör läggas till detta arkiv. Betrakta koden som ett verktyg för att ta med dig 
några av dina favoritinnehåll när du tillbringar tid på en isolerad ö.