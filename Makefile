SHELL := /bin/bash
PATH := bin:$(PATH)

syncinvoices:
	bin/samizdat makesyncinvoices

fortnox:
	bin/samizdat makefortnox

dump:
	bin/samizdat makedump

static_en:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=en LANGUAGE=en.UTF-8 LC_ALL=en_US.UTF-8 bin/samizdat makestatic

static_sv:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=sv LANGUAGE=sv.UTF-8 LC_ALL=sv_SE.UTF-8 bin/samizdat makestatic

static_de:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=de LANGUAGE=de.UTF-8 LC_ALL=de_DE.UTF-8 bin/samizdat makestatic

static_fr:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=fr LANGUAGE=fr.UTF-8 LC_ALL=fr_FR.UTF-8 bin/samizdat makestatic

static_es:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=es LANGUAGE=es.UTF-8 LC_ALL=es_ES.UTF-8 bin/samizdat makestatic

static_pl:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=pl LANGUAGE=pl.UTF-8 LC_ALL=pl_PL.UTF-8 bin/samizdat makestatic

static_pt:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=pt LANGUAGE=pt.UTF-8 LC_ALL=pt_PT.UTF-8 bin/samizdat makestatic

static_ru:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=ru LANGUAGE=ru.UTF-8 LC_ALL=ru_RU.UTF-8 bin/samizdat makestatic

static_hi:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=hi LANGUAGE=hi.UTF-8 LC_ALL=hi_IN.UTF-8 bin/samizdat makestatic

static_ar:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=ar LANGUAGE=ar.UTF-8 LC_ALL=ar_SA.UTF-8 bin/samizdat makestatic

static_zh:
	env -u LANG -u LANGUAGE -u LC_ALL LANG=zh LANGUAGE=zh.UTF-8 LC_ALL=zh_CN.UTF-8 bin/samizdat makestatic

static_all: static_en static_sv static_de static_fr static_es static_pl static_pt static_ru static_hi static_ar static_zh
	echo "All static files generated. Cache is warm."

clean:
	rm -rf public/*
	mkdir -p public/assets
	cp -af src/public/test/README.md src/public/test/README.txt

harvest:
	bin/samizdat makeharvest

nginx:
	bin/samizdat makenginx

eplinks:
	find templates/ -type l -delete
	bin/samizdat makeeplinks

iso: static_all
	xorrisofs -r -hfsplus -joliet -V Z`date +%Y%m%d_%H%M%S` --modification-date=`date +%Y%m%d%H%M%S00` -exclude public/iso/ -output public/iso/samizdat.iso public/

torrent:
	transmission-cli -n public

isotorrent: public/iso/samizdat.iso

devtools:

i18n:
	rm -f ./src/countries-data-json/data/translations/countries-zh.json
	ln -s -r src/countries-data-json/data/translations/countries-zh_CN.json ./src/countries-data-json/data/translations/countries-zh.json
	bin/samizdat makei18n

cert:
	openssl req -x509 -newkey rsa:4096 -sha256 -days 5000 -nodes \
		-keyout server.key -out server.crt \
		-subj "/C=US/ST=State/L=City/O=Example/CN=example.com" \
		-addext "subjectAltName=DNS:example.com,DNS:*.example.com,DNS:localhost,IP:127.0.0.1"
	@echo "Certificate created: server.crt (valid until ~2038)"
	@echo "Private key created: server.key"
	@openssl x509 -in server.crt -noout -text | grep -A2 "Validity"

debug:
	MOJO_MODE=development MOJO_DAEMON_DEBUG=1 DBI_TRACE=SQL morbo -m development -l http+unix://bin%2Fsamizdat.sock -l 'https://0.0.0.0:3443?cert=./server.crt&key=./server.key&reuse=1' -v -w ./lib -w ./templates -w ./script ./bin/samizdat

serverstart: zip
	MOJO_MODE=production hypnotoad ./bin/samizdat

serverstop:
	hypnotoad -s ./bin/samizdat

routes:
	bin/samizdat routes -v

test: clean
	prove -l -v
	ls -las public/test

zip:
	find public/assets -type f -name "*.css" -exec gzip -f -k -9 {} \;
	find public/assets -type f -name "*.js" -exec gzip -f -k -9 {} \;

database:
#	sudo -u postgres -i env PGHOST=/var/run/postgresql createuser --interactive --pwprompt --login --echo --no-createrole --no-createdb --no-superuser --no-replication samizdat
	sudo -u postgres -i env PGHOST=/var/run/postgresql createdb --encoding=UTF-8 --template=template0 --locale=en_US.UTF-8 --owner=samizdat samizdat "Samizdat web application"
#	sudo find /etc/postgresql -name pg_hba.conf -type f -exec sed -i -E 's/\nlocal   samizdat        samizdat                      scram-sha-256//g' {} \;
#	sudo find /etc/postgresql -name pg_hba.conf -type f -exec sed -i -E 's/(#\s+TYPE\s+DATABASE\s+USER\s+ADDRESS\s+METHOD)/\1\nlocal   samizdat        samizdat                      scram-sha-256/' {} \;
	sudo systemctl restart postgresql

fetchicons:
	git clone https://github.com/twbs/icons.git ./src/icons

fetchflags:
	git clone https://github.com/lipis/flag-icons.git ./src/flag-icons

fetchcountries:
	git clone https://github.com/countries/countries-data-json.git ./src/countries-data-json

fetchlanguages:
	git clone https://github.com/cospired/i18n-iso-languages.git ./src/i18n-iso-languages

fetchfonts:
	mkdir -p src/fonts
	wget -O src/fonts/NotoSans-Regular.ttf "https://fonts.gstatic.com/s/notosans/v36/o-0mIpQlx3QUlC5A4PNB6Ryti20_6n1iPHjcz6L1SoM-jCpoiyD9A-9a6Vc.ttf"
	wget -O /tmp/NotoSansDevanagari.zip "https://github.com/notofonts/devanagari/releases/download/NotoSansDevanagari-v2.004/NotoSansDevanagari-v2.004.zip" && unzip -j -o /tmp/NotoSansDevanagari.zip "NotoSansDevanagari/googlefonts/ttf/NotoSansDevanagari-Regular.ttf" -d src/fonts && rm /tmp/NotoSansDevanagari.zip
	wget -O /tmp/NotoSansArabic.zip "https://noto-website-2.storage.googleapis.com/pkgs/NotoSansArabic-unhinted.zip" && unzip -j -o /tmp/NotoSansArabic.zip "NotoSansArabic-Regular.ttf" -d src/fonts && rm /tmp/NotoSansArabic.zip

fetchall: fetchicons fetchflags fetchcountries fetchlanguages

speedtest:
	bin/samizdat speedtest

webpackinit:
	npm init -y
	npm i --save-dev webpack webpack-cli webpack-dev-server html-webpack-plugin webpack-merge
	npm i --save-dev autoprefixer css-loader postcss-loader sass sass-loader style-loader
	npm i --save-dev purgecss purgecss-webpack-plugin
	npm i --save-dev mini-css-extract-plugin
	npm i --save-dev css-minimizer-webpack-plugin clean-webpack-plugin
	npm i --save-dev image-minimizer-webpack-plugin svgo sharp katex
	npm i --save bootstrap @popperjs/core
	npm i --save suneditor
	npm i --save bootstrap-icons
	npm i --save sprintf-js

webpack:
	mkdir -p public/assets
	npm install
	MOJO_MODE=production npm run build

favicon:
	convert src/svg/f.svg -background none -bordercolor white -border 0 \
	  \( -clone 0 -resize 16x16 \) \
	  \( -clone 0 -resize 32x32 \) \
	  \( -clone 0 -resize 48x48 \) \
	  \( -clone 0 -resize 64x64 \) \
      -alpha off -colors 256 -delete 0 public/favicon.ico
	gzip -f -k -9 public/favicon.ico

icons:
	bin/samizdat makeicons

install: clean favicon icons static_all webpack zip
#	chown -R www:www .

# Install runscript - works for both FreeBSD and Linux
install-rc:
	@if [ -d /usr/local/etc/rc.d ]; then \
		echo "Installing FreeBSD rc script..."; \
		sed 's/myapp/samizdat/g' myapp.rc > /tmp/samizdat.rc.tmp; \
		install -o root -g wheel -m 555 /tmp/samizdat.rc.tmp /usr/local/etc/rc.d/samizdat; \
		rm -f /tmp/samizdat.rc.tmp; \
		echo "RC script installed. Add samizdat_enable=\"YES\" and samizdat_dir=\"$$(pwd)\" to /etc/rc.conf"; \
	elif [ -d /etc/init.d ]; then \
		echo "Installing Linux init script..."; \
		sed 's/myapp/samizdat/g' myapp.rc > /tmp/samizdat.rc.tmp; \
		install -o root -g root -m 755 /tmp/samizdat.rc.tmp /etc/init.d/samizdat; \
		rm -f /tmp/samizdat.rc.tmp; \
		if command -v systemctl >/dev/null 2>&1; then \
			echo "Systemd detected. You may want to create a systemd service file instead."; \
		else \
			update-rc.d samizdat defaults 2>/dev/null || chkconfig --add samizdat 2>/dev/null || true; \
			echo "Init script installed. Start with: service samizdat start"; \
		fi; \
	else \
		echo "Error: Unable to detect init system location"; \
		exit 1; \
	fi

import:
	bin/samizdat makeimport

installdata:
	bin/samizdat makeinstalldata

purgedata:
	sudo systemctl restart postgresql
#	sudo -u postgres env PGHOST=/var/run/postgresql psql -c 'TRUNCATE account.user RESTART IDENTITY;' -d samizdat -e
	sudo -u postgres env PGHOST=/var/run/postgresql psql -c 'DROP DATABASE samizdat;' -e

purgeuncompressed:
	find public -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.json" -o -name "*.txt" \) ! -name "*.gz" -delete
