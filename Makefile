static:
	bin/samizdat makestatic

clean:

harvest:

iso: harvest static

torrent:
	mkisofs ...

isotorrent: iso