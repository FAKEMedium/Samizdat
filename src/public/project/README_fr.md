[description]: # "Samizdat est une nouvelle approche de l'auto-édition qui utilise la technologie moderne."
[keywords]: # "édition,Samizdat"

# Projet Samizdat

Dans l'ancien bloc de l'Est où la liberté d'expression était interdite, les gens utilisaient d'autres méthodes. Le mouvement clandestin de reproduction et de distribution manuelle de textes s'appelait samizdat.

* En savoir plus sur [l'utilisation et l'installation](installation/)
* Comment vous pouvez [contribuer](../contribute/)

### Points forts

* Support de l'internationalisation
* Formats lisibles par l'homme &mdash; YAML et Markdown
* Optimisation de la vitesse &mdash; images WebP automatiques, mise en cache intelligente du contenu généré, minimisation
* HTML5 sémantique et joliment formaté
* Modèles intelligents Mojolicious
* Mises en page automatiques à une ou deux colonnes avec panneaux latéraux concaténés
* Fonction d'aide pour [l'intégration facile d'images SVG](./icons/)
* Fonction d'aide pour les [données de pays](../../country/)

### Structure des répertoires

* bin - Scripts
* lib - Modules Perl
  * Samizdat
    * Command - Modules Perl qui ajoutent des options à la commande samizdat.
* public - Fichiers statiques. Markdown. Les fichiers traités sont également stockés ici en tant que contenu mis en cache.
* t - Suite de tests
* templates - Modèles, mises en page et petits fragments

Les fichiers du répertoire public sont ceux qui vont dans l'image disque (format ISO) pour être consultés localement. 
Il est également possible d'utiliser un serveur web et de servir du contenu ultra-rapide. J'espère trouver également une 
solution Bittorrent pour diffuser des vidéos. Fakenews.com utilisera Samizdat pendant une période et aura des mises à jour régulières.

### Piratage à usage personnel

Aucun matériel média ne doit être ajouté à ce dépôt. Considérez le code comme un outil pour emporter certains de vos contenus 
préférés lorsque vous passez du temps sur une île isolée.