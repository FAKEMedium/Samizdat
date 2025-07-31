[description]: # "Overview of installation of the Samizdat application"
[keywords]: # "installation"

# Instalação

Samizdat deve ser instalado pelo superusuário em um VPS ou em metal puro.
Se você prefere instalação fácil e atualizações de software sem problemas, opte pela preparação do Ubuntu.
Se velocidade e ajuste fino é o que você deseja, além de ser um administrador de sistemas experiente, opte pela configuração de ports do FreeBSD.

* [Ubuntu Linux](./ubuntu/)
* [FreeBSD](./freebsd/)

Assets como CSS e JavaScript podem ser compilados e minimizados. O Samizdat também tem algumas personalizações do código Bootstrap 5.

* [Webpack](./webpack/)

Samizdat transfere o serviço de conteúdo estático para o Nginx. Outra maneira que eles trabalham juntos é compartilhando cookies através do Redis.
Um pequeno código Lua no Nginx ajuda então com a autorização.

* [Configuração Nginx / Openresty](./etc/)