# Installation

To build the disk image you need a recent version of Perl. Then grab the Mojolicious package.
The different tasks are managed by make. These steps are suggestions:

* Start with an [Ubuntu installation](https://ubuntu.com/download/server)
* Run commands to install stuff
  * sudo apt update
  * sudo apt install cpanminus make mkisofs xorriso growisofs transmission-cli libwebp-dev git automake autoconf
  * sudo cpanm Mojolicious
  * sudo cpanm WWW::YouTube::Download
  * sudo cpanm Hash::Merge
  * sudo cpanm Text::MultiMarkdown
  * sudo cpanm Mojolicious::Plugin::LocaleTextDomainOO
  * sudo cpanm Locale::TextDomain::OO::Extract
  * sudo cpanm Imager::File::WEBP MojoX::MIME::Types
* Clone the project into a suitable directory
  * git clone git clone https://github.com/FakenewsCom/Samizdat.git
  * cd Samizdat
* Copy samizdat.dist.yml to samizdat.yml and modify it for your needs

## Operation

These tasks are defined in the Makefile and are meant to be run from the application root directory

* make static - Process markdown files
* make harvest - Start the web crawler to fetch material from our list of sources
* make clean - Remove all html and media files from the public directory
* make iso - Calculates the size on disk of the public directory and builds a DVD or Blu-ray ISO image
* make torrent - Makes a torrent file of the public directory. If Pirate Bay login credentials are defined 
in [samizdat.yml](../../../samizdat.yml) the torrent file will be published too.
* make isotorrent - Makes torrent files for existing ISO images.
* make devtools - Bootstraps an Ubuntu live image with everything installed to make contributions easy
* make i18n  - Manage script internationalization
* make debug - Start the Morbo web server. It has lots of useful information for debugging