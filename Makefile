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

potfiles:
	samizdat makepotfiles

locale: potfiles
	cd locale
	make all