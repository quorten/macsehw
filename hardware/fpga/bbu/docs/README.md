# Associated Documentation

These are references to useful reference documentation when working
with the BBU design, mostly datasheets.  See `index.md` for links
with descriptions and `getsheets.sh` for a script to download them all
locally.

Also, it's helpful to consult the software pin assignments on the VIA
when working with the BBU, I've created `VIA.txt` as a quick reference
for this, so you don't have to read through several pages of _Guide to
the Macintosh family hardware_.

----------

Wondering what the cryptic D-P SAMI option in the Macintosh SE
schematics is?  This has to do with the fact that row 1 and row 2 in
resistored versus jumpered Macintoshes behave differently.  row 2
(SIMM 3 and 4) contains the larger RAM SIMMs in jumpered versions, row
1 (SIMM 1 and 2) contains the larger RAM SIMMs in resistored versions.
