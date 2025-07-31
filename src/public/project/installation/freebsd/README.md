[description]: # "Commands to install the Samizdat needed base programs on a FreeBSD server."
[keywords]: # "FreeBSD,Perl,PostgreSQL,pkg"

# Installation for FreeBSD

FreeBSD use of kqueue instead of epoll for dealing with kernel events should make it a little faster than Linux,
at least with latency.
Also, Ubuntu has started to offer some upgrades only through paid subscriptions.
These instructions use [the pkg utility](https://docs.freebsd.org/en/books/handbook/ports/#pkgng-intro).
Specialists may build customized ports instead.

