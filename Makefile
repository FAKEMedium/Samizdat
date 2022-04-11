SHELL := /bin/bash
PATH := bin:$(PATH)

static:
	samizdat makestatic

clean:
	find public/  -name "*.html" -delete

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
	MOJO_LISTEN=http://0.0.0.0:3000 MOJO_MODE=development samizdat daemon


server:
	MOJO_LISTEN=http://0.0.0.0:3000 MOJO_MODE=production samizdat prefork

routes:
	samizdat routes -v