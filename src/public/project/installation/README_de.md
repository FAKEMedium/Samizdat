[description]: # "Overview of installation of the Samizdat application"
[keywords]: # "installation"

# Installation

Samizdat soll vom Superuser auf einem VPS oder auf Bare Metal installiert werden.
Wenn Sie eine einfache Installation und reibungslose Software-Upgrades bevorzugen, wählen Sie die Ubuntu-Vorbereitung.
Wenn Geschwindigkeit und Feinabstimmung Ihr Wunsch sind und Sie ein erfahrener Systemadministrator sind, wählen Sie die FreeBSD-Ports-Einrichtung.

* [Ubuntu Linux](./ubuntu/)
* [FreeBSD](./freebsd/)

Assets wie CSS und JavaScript können kompiliert und minimiert werden. Samizdat hat auch einige Anpassungen am Bootstrap 5-Code.

* [Webpack](./webpack/)

Samizdat lagert das Bereitstellen von statischen Inhalten an Nginx aus. Eine andere Art der Zusammenarbeit ist das Teilen von Cookies über Redis.
Etwas Lua-Code in Nginx hilft dann bei der Autorisierung.

* [Nginx / Openresty-Konfiguration](./etc/)