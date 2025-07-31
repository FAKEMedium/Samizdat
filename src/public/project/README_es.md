[description]: # "Samizdat es un nuevo enfoque de la autopublicación que utiliza tecnología moderna."
[keywords]: # "publicación,Samizdat"

# Proyecto Samizdat

En el antiguo Bloque del Este, donde la libertad de expresión estaba prohibida, la gente utilizaba otros métodos. El movimiento clandestino de base para la reproducción manual y distribución de textos se llamaba samizdat.

* Aprenda sobre [uso e instalación](installation/)
* Cómo puede [contribuir](../contribute/)

### Características destacadas

* Soporte para internacionalización
* Formatos legibles por humanos &mdash; YAML y Markdown
* Optimización de velocidad &mdash; imágenes WebP automáticas, almacenamiento inteligente en caché de contenido generado, minimización
* HTML5 semántico y bien formateado
* Plantillas inteligentes de Mojolicious
* Diseños automáticos de una o dos columnas con paneles laterales concatenados
* Función auxiliar para [incrustar fácilmente imágenes SVG](./icons/)
* Función auxiliar para [datos de países](../../country/)

### Estructura de directorios

* bin - Scripts
* lib - Módulos de Perl
  * Samizdat
    * Command - Módulos de Perl que añaden opciones al comando samizdat.
* public - Archivos estáticos. Markdown. Los archivos procesados también se almacenan aquí como contenido en caché.
* t - Suite de pruebas
* templates - Plantillas, layouts y fragmentos más pequeños

Los archivos en el directorio public son los que se incluyen en la imagen de disco (formato ISO) para ser visualizados localmente. 
También es posible utilizar un servidor web y servir contenido ultrarrápido. Con suerte, también encontraré una solución 
Bittorrent para transmitir video. Fakenews.com utilizará Samizdat durante un período y tendrá actualizaciones regulares.

### Piratería de uso personal

No se debe añadir material multimedia a este repositorio. Considere el código como una herramienta para llevar consigo parte de su 
contenido favorito cuando pase tiempo en una isla aislada.