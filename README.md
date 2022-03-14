# Samizdat
Documenting differences in media coverage of the war in Ukraine

In the former Eastern Bloc where free speach was prohibited people used other methods. The underground 
grassroot movement of manual reproduction and distribution of text was called samizdat.

As media no longer can report freely in Russia there are incredible differences in what is reported
by government controlled media and what the rest of the world can see. As foreign news sites sometimes 
are filtered this repository aims to provide tools to fetch some representative content and use it to 
create a disk image that can be downloaded as a torrent file.

* Learn about [usage and installation](./INSTALL.md)
* How you can [contribute](./pages/contributing/README.md)

### Directory structure
* bin - Scripts
* lib - Perl modules
  * Samizdat
    * Command - Perl modules that adds options to the [samizdat command](./bin/samizdat)
* pages - Markdown files that will be processed
* public - Static files. Processed files go here too.
* sources.d - yml files for collecting media from different news sites
* t - Test suite
* templates - Templates, layouts and smaller chunks

The files in the public directory are what goes into the disk image (ISO format) to be viewed locally. 
It is also possible to use a web server and serve lightning fast content. Hopefully we'll find a Bittorrent
solution to stream video too. Fakenews.com will use Samizdat for a period, and have regular updates.


### Personal usage piracy
No media material should be added to this repository. Consider the code as a tool to take some of your favourite 
content with you as you spend time on an isolated island.