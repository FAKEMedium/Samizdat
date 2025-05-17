# Projeto Samizdat

No antigo Bloco Oriental, onde a liberdade de expressão era proibida, as pessoas usavam outros métodos. O movimento clandestino de base para reprodução manual e distribuição de textos era chamado samizdat.

* Saiba mais sobre [uso e instalação](installation/)
* Como você pode [contribuir](../contribute/)

### Destaques

* Suporte à internacionalização
* Formatos legíveis por humanos &mdash; YAML e Markdown
* Otimização de velocidade &mdash; imagens WebP automáticas, cache inteligente de conteúdo gerado, minimização
* HTML5 semântico e bem formatado
* Templates inteligentes Mojolicious
* Layouts automáticos de uma ou duas colunas com painéis laterais concatenados
* Função auxiliar para [incorporação fácil de imagens SVG](./icons/)
* Função auxiliar para [dados de países](../../country/)

### Estrutura de diretórios

* bin - Scripts
* lib - Módulos Perl
  * Samizdat
    * Command - Módulos Perl que adicionam opções ao comando samizdat.
* public - Arquivos estáticos. Markdown. Arquivos processados também vão aqui como conteúdo em cache.
* t - Suite de testes
* templates - Templates, layouts e fragmentos menores

Os arquivos no diretório public são os que vão para a imagem de disco (formato ISO) para serem visualizados localmente. 
Também é possível usar um servidor web e servir conteúdo extremamente rápido. Espero encontrar também uma solução 
Bittorrent para transmitir vídeo. Fakenews.com usará o Samizdat por um período e terá atualizações regulares.

### Pirataria para uso pessoal

Nenhum material de mídia deve ser adicionado a este repositório. Considere o código como uma ferramenta para levar 
consigo alguns dos seus conteúdos favoritos enquanto passa tempo em uma ilha isolada.