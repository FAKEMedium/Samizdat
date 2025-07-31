[description]: # "Overview of installation of the Samizdat application"
[keywords]: # "installation"

# Installation

Samizdat är tänkt att installeras av superanvändaren på en VPS eller på ren hårdvara.
Om du föredrar enkel installation och smidiga programvaruuppgraderingar, välj Ubuntu-förberedelser.
Om hastighet och finjustering är vad du önskar, plus att du är en skicklig systemadministratör, välj FreeBSD-ports-konfigurationen.

* [Ubuntu Linux](./ubuntu/)
* [FreeBSD](./freebsd/)

Tillgångar som css och javascript kan kompileras och minimeras. Samizdat har också några anpassningar av Bootstrap 5-koden.

* [Webpack](./webpack/)

Samizdat lägger ut servering av statiskt innehåll till Nginx. Ett annat sätt de arbetar tillsammans på är genom att dela cookies via Redis.
Lite Lua-kod i Nginx hjälper sedan till med auktorisering.

* [Nginx / Openresty-konfiguration](./etc/)