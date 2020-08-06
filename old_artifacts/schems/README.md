These are links to the official Apple Macintosh SE schematics.

Source website: https://museo.freaknet.org/gallery/apple/stuff/mac/andreas.kann/schemat.html

Unfortunately, there are no BOMARC schematics available for the
Macintosh SE.

The Internet Archive also has a copy of purportedly the same Macintosh
SE schematics scan.

https://archive.org/details/Macintosh68kSchematics

----------

Due to the illegiblity of the original Main Logic Board (MLB) page 1
scan, this repository also contains a [retrace of the
schematic](retrace_se_mlb_p1.pdf), striving to be as faithful as
possible to the original.  The retrace was done by hand and careful
eyeing in Inkscape, after doing some simple image processing on the
input scan.  A script that uses the ImageMagick `convert` command is
included to reproduce the processing steps.

Notes related to the accuracy of the retrace.

* The pinouts of all integrated circuit components have been verified
  with second sources.

* The pinouts of the PDS slot and RAM SIMMs have **not** yet been
  verified with second sources.

* The resistor values have been checked to be consistent with the
  reference designators, but **not all reference designators** have
  been verified to be consistent with the placement on the printed
  circuit board.

* The schematic info blocks in the upper and lower left corners have
  been cross-checked with scans of other official Apple schematics to
  attempt to make them as faithful as possible to the original
  contents.

Notes on the source SVG file:

* The processed scan is linked as a hidden and locked image object.
  To view both the retrace and the original scan together, find the
  image object (possibly in the XML hierarchy) and make it visible.
  The image object is locked to make it easier to draw on top of.

* The specific `sans-serif` font I used on my system is DejaVu Sans.
  So long as your system `sans-serif` font has similar metrics,
  everything should work just fine, otherwise you can replace the font
  family name with DejaVu Sans.
