# Projekt Samizdat

W byłym Bloku Wschodnim, gdzie wolność słowa była zakazana, ludzie używali innych metod. Podziemny ruch oddolny ręcznego powielania i dystrybucji tekstów nazywał się samizdatem.

* Dowiedz się o [użytkowaniu i instalacji](installation/)
* Jak możesz [przyczynić się](../contribute/)

### Wyróżniki

* Wsparcie dla internacjonalizacji
* Formaty czytelne dla człowieka &mdash; YAML i Markdown
* Optymalizacja prędkości &mdash; automatyczne obrazy WebP, inteligentne buforowanie generowanej treści, minimalizacja
* Pięknie sformatowany i semantyczny HTML5
* Inteligentne szablony Mojolicious
* Automatyczne układy jedno- lub dwukolumnowe z połączonymi panelami bocznymi
* Funkcja pomocnicza do [łatwego osadzania obrazów SVG](./icons/)
* Funkcja pomocnicza do [danych o krajach](../../country/)

### Struktura katalogów

* bin - Skrypty
* lib - Moduły Perl
  * Samizdat
    * Command - Moduły Perl, które dodają opcje do polecenia samizdat.
* public - Pliki statyczne. Markdown. Przetworzone pliki również trafiają tutaj jako zbuforowane treści.
* t - Zestaw testów
* templates - Szablony, układy i mniejsze fragmenty

Pliki w katalogu public to te, które trafiają do obrazu dysku (format ISO) do lokalnego przeglądania. 
Możliwe jest również użycie serwera internetowego i serwowanie błyskawicznie szybkich treści. Mam nadzieję, 
że znajdę również rozwiązanie Bittorrent do strumieniowania wideo. Fakenews.com będzie korzystać z Samizdatu 
przez pewien okres i mieć regularne aktualizacje.

### Piractwo do użytku osobistego

Do tego repozytorium nie należy dodawać materiałów medialnych. Traktuj kod jako narzędzie do zabrania ze sobą 
niektórych ulubionych treści, gdy spędzasz czas na odizolowanej wyspie.