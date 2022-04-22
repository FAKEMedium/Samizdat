SHELL := /bin/bash
PATH := bin:$(PATH)

static:
	samizdat makestatic

clean:
	find public/  -name "*.html" -delete
	find public/  -name "*.gz" -delete
	rm -f public/test/Brown_Mushroom_on_the_Green_Grass.webp

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
	morbo -m development -l http://0.0.0.0:3000?reuse=1 -l http+unix://%2Ftmp%2Fsamizdat.sock -v -w ./ ./bin/samizdat

server: clean zip
	MOJO_MODE=production hypnotoad ./bin/samizdat

routes:
	samizdat routes -v

test:
	prove -l -v

zip:
	gzip -k -9 public/css/bundle.css
	gzip -k -9 public/js/bundle.js