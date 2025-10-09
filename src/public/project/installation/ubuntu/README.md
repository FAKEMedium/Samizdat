[description]: # "Commands to install Samizdat on Ubuntu."
[keywords]: # "Mojolicious,perl,linux,ubuntu"

# Ubuntu Installation

Ubuntu 20.04 LTS or later.

### System packages

* `sudo apt update`
* `sudo apt install -y build-essential cpanminus git make automake autoconf cmake wget`
* `sudo apt install -y libwebp-dev libgif-dev libjpeg-dev libpng-dev libtiff-dev libheif-dev libgd-dev`
* `sudo apt install -y imagemagick librsvg2-bin librsvg2-dev pngquant`
* `sudo apt install -y postgresql postgresql-client postgresql-server-dev-all redis-server libhiredis-dev`
* `sudo apt install -y libargon2-dev uuid-dev libevdev-dev libhtml-tidy-perl`
* `sudo apt install -y mkisofs xorriso growisofs transmission-cli nginx-full apache2-utils`
* `sudo apt install -y texlive-base texlive-latex-base texlive-latex-recommended texlive-fonts-recommended`
* `sudo apt install -y texlive-latex-extra texlive-lang-european`

### Perl modules

Set cores for parallel builds:

* `export CORES=$(nproc)`

Install modules:

* `sudo cpanm --configure-args="-j$CORES" Mojolicious EV Mojo::Pg Mojo::Redis DBD::Pg`
* `sudo cpanm --configure-args="-j$CORES" Imager Imager::File::JPEG Imager::File::GIF Imager::File::PNG Imager::File::TIFF Imager::File::HEIF Imager::File::WEBP`
* `sudo cpanm --configure-args="-j$CORES" Mojolicious::Plugin::LocaleTextDomainOO Locale::TextDomain::OO::Extract`
* `sudo cpanm --configure-args="-j$CORES" Crypt::Argon2 Crypt::PBKDF2 Digest::SHA Digest::SHA1 App::bmkpasswd Bytes::Random::Secure::Tiny`
* `sudo cpanm --configure-args="-j$CORES" Data::UUID UUID DateTime DateTime::TimeZone Date::Calc Date::Format Hash::Merge`
* `sudo cpanm --configure-args="-j$CORES" Text::MultiMarkdown MojoX::MIME::Types IO::Compress::Gzip YAML::XS`
* `sudo cpanm --configure-args="-j$CORES" MIME::Base64 MIME::Lite MIME::Types File::Spec File::MimeInfo Time::HiRes`
* `sudo cpanm --configure-args="-j$CORES" HTML::FormatText HTML::TreeBuilder Business::Tax::VAT::Validation`
* `sudo cpanm --configure-args="-j$CORES" Mojolicious::Plugin::Captcha Mojolicious::Plugin::Mail Mojolicious::Plugin::Util::RandomString Test::Harness`

### Database

* `sudo -u postgres createuser samizdat -P`
* `sudo -u postgres createdb -O samizdat -E UTF-8 -T template0 --locale=en_US.UTF-8 samizdat`
* `sudo systemctl enable redis-server postgresql`
* `sudo systemctl start redis-server postgresql`

Edit `/etc/postgresql/*/main/pg_hba.conf`, add: `local   samizdat        samizdat        scram-sha-256`

Then: `sudo systemctl restart postgresql`

### Application

* `sudo mkdir -p /sites && cd /sites`
* `sudo git clone https://github.com/FakenewsCom/Samizdat.git && cd Samizdat`
* `sudo chown -R www-data:www-data /sites/Samizdat`
* `sudo -u www-data cp samizdat.dist.yml samizdat.yml`
* `sudo -u www-data nano samizdat.yml` - Edit config
* `sudo -u www-data make fetchall && sudo -u www-data bin/samizdat migrate && sudo -u www-data make i18n`

Optional Webpack frontend:

* `curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -`
* `sudo apt-get install -y nodejs`
* `sudo -u www-data make webpackinit && sudo -u www-data make webpack`

SSL cert (dev):

* `sudo -u www-data make cert`

### Usage

* `make debug` - Dev server (https://localhost:3443)
* `make serverstart/stop` - Production
* `make static_all/en/sv` - Generate content cache
* `make i18n test routes` - Dev tasks
* `make webpack` - Build assets
* `make iso` - ISO
* `bin/samizdat migrate` - DB migrations