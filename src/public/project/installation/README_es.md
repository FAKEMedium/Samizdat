# Instalación

Samizdat está diseñado para ser instalado por el superusuario en un VPS o en metal puro.
Si prefiere una instalación fácil y actualizaciones de software sin problemas, opte por la preparación de Ubuntu.
Si lo que desea es velocidad y ajuste fino, además de ser un administrador de sistemas experimentado, opte por la configuración de puertos de FreeBSD.

* [Ubuntu Linux](./ubuntu/)
* [FreeBSD](./freebsd/)

Los activos como CSS y JavaScript se pueden compilar y minimizar. Samizdat también tiene algunas personalizaciones del código de Bootstrap 5.

* [Webpack](./webpack/)

Samizdat delega la entrega de contenido estático a Nginx. Otra forma en que trabajan juntos es compartiendo cookies a través de Redis.
Un pequeño código Lua en Nginx ayuda entonces con la autorización.

* [Configuración de Nginx / Openresty](./etc/)