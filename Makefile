SHELL := /bin/bash
PATH := bin:$(PATH)

static:
	samizdat makestatic

clean:
	find public/  -name "*.html" -delete
	find public/  -name "*.gz" -delete

harvest:
	samizdat makeharvest

iso: harvest static

torrent:
	transmission-cli -n public

isotorrent: public/iso

devtools:

i18n:
	samizdat makei18n

debug:
	MOJO_LISTEN=http://0.0.0.0:3000 MOJO_MODE=development morbo -v -w ./ ./bin/samizdat

server: clean zip
	MOJO_MODE=production hypnotoad ./bin/samizdat
	chown www-data.www-data /tmp/samizdat.sock

routes:
	samizdat routes -v

test:
	prove -l -v

zip:
	gzip -k -9 public/css/bundle.css
	gzip -k -9 public/js/bundle.js