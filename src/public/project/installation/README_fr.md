# Installation

Samizdat est destiné à être installé par le superutilisateur sur un VPS ou sur du métal nu.
Si vous préférez une installation facile et des mises à jour logicielles en douceur, optez pour la préparation Ubuntu.
Si la vitesse et le réglage fin sont ce que vous désirez, et que vous êtes un administrateur système expérimenté, optez pour la configuration des ports FreeBSD.

* [Ubuntu Linux](./ubuntu/)
* [FreeBSD](./freebsd/)

Les assets comme CSS et JavaScript peuvent être compilés et minimisés. Samizdat a aussi quelques personnalisations du code Bootstrap 5.

* [Webpack](./webpack/)

Samizdat délègue la diffusion de contenu statique à Nginx. Une autre façon dont ils travaillent ensemble est en partageant des cookies via Redis.
Un petit code Lua dans Nginx aide alors à l'autorisation.

* [Configuration Nginx / Openresty](./etc/)