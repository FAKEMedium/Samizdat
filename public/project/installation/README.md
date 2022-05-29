# Installation

To build the disk image you need a recent version of Perl. Then grab the Mojolicious package.
The different tasks are managed by make. These steps are suggestions:

* Start with an [Ubuntu installation](https://ubuntu.com/download/server)
* Run commands to install stuff. This is a good-to-have list that needs some shortening.
  * sudo apt update
  * sudo apt install --yes cpanminus git make automake autoconf cmake wget libevdev-dev libhtml-tidy-perl
  * sudo apt install --yes mkisofs xorriso growisofs transmission-cli
  * sudo apt install --yes libwebp-dev libgif-dev libjpeg-dev libpng-dev libtiff-dev libheif-dev
  * sudo apt install --yes postgresql-client postgresql-12 postgresql-server-dev-all redis-server libhiredis-dev libargon2-dev
  * sudo apt install --yes nginx-full
  * sudo cpanm --reinstall EV
  * sudo cpanm --reinstall Mojolicious
  * sudo cpanm --reinstall WWW::YouTube::Download
  * sudo cpanm --reinstall Hash::Merge
  * sudo cpanm --reinstall Text::MultiMarkdown
  * sudo cpanm --reinstall Mojolicious::Plugin::LocaleTextDomainOO
  * sudo cpanm --reinstall Locale::TextDomain::OO::Extract
  * sudo cpanm --reinstall Imager
  * sudo cpanm --reinstall Imager::File::JPEG
  * sudo cpanm --reinstall Imager::File::GIF
  * sudo cpanm --reinstall Imager::File::PNG
  * sudo cpanm --reinstall Imager::File::TIFF
  * sudo cpanm --reinstall Imager::File::HEIF
  * sudo cpanm --reinstall MojoX::MIME::Types
  * sudo cpanm --reinstall IO::Compress::Gzip
  * sudo cpanm --reinstall Test::Harness
  * sudo cpanm --reinstall Mojo::Redis
  * sudo cpanm --reinstall Mojo::Pg
  * sudo cpanm --reinstall Future::AsyncAwait
  * sudo cpanm --reinstall Minion
  * sudo cpanm --reinstall Bytes::Random::Secure::Tiny
  * sudo cpanm --reinstall Crypt::Argon2
  * sudo cpanm --reinstall Crypt::PBKDF2
  * sudo cpanm --reinstall Digest::SHA1
* Clone the project into a suitable directory, we use /sites
  * sudo mkdir /sites
  * cd /sites
  * sudo -u www-data git clone https://github.com/FakenewsCom/Samizdat.git
  * cd Samizdat
* Copy samizdat.dist.yml to samizdat.yml and modify it for your needs
* Start [webpack](./webpack/) file watching to minimize files


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

## Integration

Explore [configuration examples](./etc/) to quickly deploy a fast and stable installation.