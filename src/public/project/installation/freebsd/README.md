[description]: # "Commands to install Samizdat on FreeBSD."
[keywords]: # "FreeBSD,Perl,PostgreSQL,pkg"

# FreeBSD Installation

FreeBSD 13.0+ using [pkg utility](https://docs.freebsd.org/en/books/handbook/ports/#pkgng-intro).

### System packages

* `sudo pkg update`
* `sudo pkg install -y git gmake cmake wget pkgconf perl5 p5-App-cpanminus`
* `sudo pkg install -y webp giflib jpeg-turbo png tiff libheif ImageMagick7 librsvg2 pngquant`
* `sudo pkg install -y postgresql16-server postgresql16-client redis`
* `sudo pkg install -y libargon2 e2fsprogs-libuuid texlive-base texlive-texmf`
* `sudo pkg install -y nginx apache24 xorriso cdrkit-genisoimage transmission-cli`

### Perl modules

Install modules:

* `sudo cpanm Mojolicious EV Mojo::Pg Mojo::Redis DBD::Pg`
* `sudo cpanm GD Imager Imager::File::JPEG Imager::File::GIF Imager::File::PNG Imager::File::TIFF Imager::File::HEIF Imager::File::WEBP`
* `sudo cpanm Mojolicious::Plugin::LocaleTextDomainOO Locale::TextDomain::OO::Extract`
* `sudo cpanm Params::Classify Params::Util Params::Validate Crypt::Argon2 Crypt::PBKDF2 Crypt::Eksblowfish::Bcrypt Digest::SHA Digest::SHA1 App::bmkpasswd Bytes::Random::Secure::Tiny`
* `sudo cpanm Clone Data::UUID UUID DateTime DateTime::TimeZone Date::Calc Date::Format Hash::Merge`
* `sudo cpanm Text::MultiMarkdown MojoX::MIME::Types IO::Compress::Gzip YAML::XS`
* `sudo cpanm MIME::Base64 MIME::Lite MIME::Types File::Spec File::MimeInfo Time::HiRes`
* `sudo cpanm --force HTML::Parser`
* `sudo cpanm HTML::FormatText HTML::TreeBuilder Business::Tax::VAT::Validation`
* `sudo cpanm Session::Token Mojolicious::Plugin::Captcha Mojolicious::Plugin::Mail Mojolicious::Plugin::Util::RandomString Test::Harness`

### Database

* `sudo /usr/local/etc/rc.d/postgresql oneinitdb`
* `sudo sysrc postgresql_enable=YES redis_enable=YES`
* `sudo service postgresql start && sudo service redis start`
* `sudo -u postgres createuser -P samizdat`
* `sudo -u postgres createdb -O samizdat -E UTF-8 -T template0 --locale=en_US.UTF-8 samizdat`

Edit `/usr/local/pgsql/data/pg_hba.conf`, add: `local   samizdat        samizdat        scram-sha-256`

Then: `sudo service postgresql restart`

### Application

* `sudo mkdir -p /sites && cd /sites`
* `sudo git clone https://github.com/FakenewsCom/Samizdat.git && cd Samizdat`
* `sudo chown -R www:www /sites/Samizdat`
* `sudo -u www cp samizdat.dist.yml samizdat.yml && sudo -u www vi samizdat.yml`
* `sudo -u www gmake fetchall && sudo -u www bin/samizdat migrate && sudo -u www gmake i18n`

Optional Webpack frontend:

* `sudo pkg install -y node npm`
* `sudo -u www gmake webpackinit && sudo -u www gmake webpack`

SSL cert (dev):

* `sudo -u www gmake cert`

### Usage

* `gmake debug` - Dev server (https://localhost:3443)
* `gmake serverstart/stop` - Production
* `gmake static_all/en/sv` - Generate content cache
* `gmake i18n test routes` - Dev tasks
* `gmake webpack` - Build assets
* `gmake iso` - Build ISO file
* `bin/samizdat migrate` - DB migrations

### Jails & Service

For jails: ensure network access, mount devfs, configure port forwarding.

Copy `samizdat.rc` to `/usr/local/etc/rc.d/samizdat`, then enable with: `sudo chmod +x /usr/local/etc/rc.d/samizdat && sudo sysrc samizdat_enable=YES`

Performance tuning in `/etc/sysctl.conf`:

* `kern.maxfiles=100000`
* `kern.maxfilesperproc=50000`
* `net.inet.tcp.sendspace=65536`
* `net.inet.tcp.recvspace=65536`