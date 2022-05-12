# Samizdat project

In the former Eastern Bloc where free speech was prohibited people used other methods. The underground 
grassroot movement of manual reproduction and distribution of text was called samizdat.

As media no longer can report freely in Russia there are incredible differences in what is reported
by government controlled media and what the rest of the world can see. As foreign news sites sometimes 
are filtered this repository aims to provide tools to fetch some representative content and use it to 
create a disk image that can be downloaded as a torrent file.

* Learn about [usage and installation](installation/)
* How you can [contribute](../contribute/)

### Highlights

* Internationalization support
* Human readable formats &mdash; YAML and Markdown
* Speed optimization &mdash; automatic WebP images, smart caching of generated content, minimization
* Beautiful and semantic html5
* Mojolicious smart templates
* Automatic one or two column layouts with concatenated side panels

### Directory structure
* bin - Scripts
* lib - Perl modules
  * Samizdat
    * Command - Perl modules that adds options to the samizdat command.
* public - Static files. Markdown. Processed files go here too as cached content.
* t - Test suite
* templates - Templates, layouts and smaller chunks

The files in the public directory are what goes into the disk image (ISO format) to be viewed locally. 
It is also possible to use a web server and serve lightning fast content. Hopefully I'll find a Bittorrent
solution to stream video too. Fakenews.com will use Samizdat for a period, and have regular updates.

### Personal usage piracy

No media material should be added to this repository. Consider the code as a tool to take some of your favourite 
content with you as you spend time on an isolated island.