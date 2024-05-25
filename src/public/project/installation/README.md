# Installation

Samizdat is supposed to be installed by the superuser on a VPS or on bare metal.
If you prefer easy installation and smooth software upgrades, go with the Ubuntu preparation.
If speed and fine tuning is what you desire, plus you're a skilled sysop, go with the FreeBSD ports setup.

* [Ubuntu Linux](./ubuntu/)
* [FreeBSD](./freebsd/)

Assets like css and javascript can be compiled and minimized. Samizdat has some customizations of the Bootstrap 5 code too.

* [Webpack](./webpack/)

Samizdat offloads serving of static content to Nginx. An other way they work together is by sharing cookies through Redis.
Some small Lua code in Nginx then helps authorization.

* [Nginx / Openresty configuration](./etc/)