SHELL := /bin/bash
PATH := bin:$(PATH)


static:
	samizdat makestatic

clean:

harvest:
	samizdat makeharvest

iso: harvest static

torrent:
	mkisofs ...

isotorrent: iso

devtools: