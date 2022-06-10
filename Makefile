SHELL := /bin/bash
PATH := bin:$(PATH)

static:
	LANG=en LANGUAGE=en.UTF-8 LC_ALL=en_US.UTF-8 samizdat makestatic

clean:
	find public/  -name "*.html" -delete
	find public/  -name "*.gz" -delete
	rm -f public/test/Brown_Mushroom_on_the_Green_Grass.webp

harvest:
	samizdat makeharvest

nginx:
	samizdat makenginx

iso: static
	xorrisofs -r -hfsplus -joliet -V Z`date +%Y%m%d_%H%M%S` --modification-date=`date +%Y%m%d%H%M%S00` -exclude public/iso/ -output public/iso/samizdat.iso public/

torrent:
	transmission-cli -n public

isotorrent: public/iso/samizdat.iso

devtools:

i18n:
	samizdat makei18n

debug:
	MOJO_DAEMON_DEBUG=1 DBI_TRACE=SQL morbo -m development -l http+unix://bin%2Fsamizdat.sock -l http://0.0.0.0:3000?reuse=1 -v -w ./ ./bin/samizdat

server: clean zip
	MOJO_MODE=production hypnotoad ./bin/samizdat

routes:
	samizdat routes -v

test: clean
	prove -l -v
	ls -las public/test

zip:
	gzip -k -9 public/css/bundle.css
	gzip -k -9 public/js/bundle.js

database:
	sudo -u postgres -i createuser --interactive --pwprompt --login --echo --no-createrole --no-createdb --no-superuser --no-replication samizdat
	sudo -u postgres -i createdb --encoding=UTF-8 --template=template0 --locale=en_US.UTF-8 --owner=samizdat samizdat "Samizdat web application"
	sudo find /etc/postgresql -name pg_hba.conf -type f -exec sed -i -E 's/\nlocal   samizdat        samizdat                                md5//g' {} \;
	sudo find /etc/postgresql -name pg_hba.conf -type f -exec sed -i -E 's/(#\s+TYPE\s+DATABASE\s+USER\s+ADDRESS\s+METHOD)/\1\nlocal   samizdat        samizdat                                md5/' {} \;
	sudo systemctl restart postgresql

fetchicons:
	git clone https://github.com/twbs/icons.git ./src/icons
