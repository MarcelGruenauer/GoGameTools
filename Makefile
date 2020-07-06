.PHONY: default thumbnails clean

THUMBNAILS = site/wgo/support/images/thumbnails

default:
	$(error Specify a Makefile target)

# https://imagemagick.org/script/color.php
thumbnails: clean
	mkdir -p $(THUMBNAILS)
	./author/gen-thumbnails -i author/thumbnails.sgf -d $(THUMBNAILS) | sh
	convert -size 320x320 xc:Red    $(THUMBNAILS)/rank-intro.png
	convert -size 320x320 xc:Orange $(THUMBNAILS)/rank-elementary.png
	convert -size 320x320 xc:Yellow $(THUMBNAILS)/rank-intermediate.png
	convert -size 320x320 xc:Green  $(THUMBNAILS)/rank-advanced.png
	convert -size 320x320 xc:Blue   $(THUMBNAILS)/rank-low-dan.png
	convert -size 320x320 xc:Red    $(THUMBNAILS)/rank-high-dan.png
	cp ./author/other-thumbnails/* $(THUMBNAILS)

clean:
	rm -rf $(THUMBNAILS)

