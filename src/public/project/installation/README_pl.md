[description]: # "Overview of installation of the Samizdat application"
[keywords]: # "installation"

# Instalacja

Samizdat powinien być instalowany przez superużytkownika na VPS lub na czystym sprzęcie.
Jeśli wolisz łatwą instalację i płynne aktualizacje oprogramowania, wybierz przygotowanie Ubuntu.
Jeśli prędkość i dostrajanie są tym, czego pragniesz, a do tego jesteś doświadczonym administratorem systemu, wybierz konfigurację portów FreeBSD.

* [Ubuntu Linux](./ubuntu/)
* [FreeBSD](./freebsd/)

Zasoby takie jak CSS i JavaScript mogą być skompilowane i zminimalizowane. Samizdat ma również pewne dostosowania kodu Bootstrap 5.

* [Webpack](./webpack/)

Samizdat przekazuje serwowanie statycznych treści do Nginx. Innym sposobem, w jaki współpracują, jest dzielenie się plikami cookie przez Redis.
Niewielki kod Lua w Nginx pomaga wtedy w autoryzacji.

* [Konfiguracja Nginx / Openresty](./etc/)