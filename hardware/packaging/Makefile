all: box-layout.pdf

mac_halftone.png:
	./get_mac_halftone.sh

box-layout.pdf: mac_halftone.png
	inkscape --export=pdf=$@ $<

mostlyclean:

clean: mostlyclean
	rm -f mac_halftone.png photos/*.JPG
