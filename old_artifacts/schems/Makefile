all: retrace_se_mlb_p1.pdf

se_mlb_p1.gif: 
	./get_scans.sh

se_mlb_p1_proc.png: se_mlb_p1.gif
	./resize-mlb-scan.sh

retrace_se_mlb_p1.pdf: retrace_se_mlb_p1.svg se_mlb_p1_proc.png
	inkscape --export-pdf=$@ $<

mostlyclean:
	rm -f se_mlb_p1_tmp.png
	rm -f se_mlb_p1_proc.png

clean: mostlyclean
	rm -f se_mlb_p1.gif
