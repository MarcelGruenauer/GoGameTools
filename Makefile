.PHONY: default thumbnails clean

THUMBNAILS = site/wgo/support/images/thumbnails

default:
	$(error Specify a Makefile target)

thumbnails: clean
	mkdir -p $(THUMBNAILS)
	./author/gen-thumbnails -i author/thumbnails.sgf -d $(THUMBNAILS) | sh
	cp ./author/other-thumbnails/* $(THUMBNAILS)

clean:
	rm -rf $(THUMBNAILS)

