# Macintosh SE Cardboard Box Specifications

All dimensions in inches, unless otherwise specified.

Principal box measurements: 19.5 x 20 (height) x 15.5

The cardboard box structure is that of a Regular Slotted Container
(RSC).

* All flaps are of the same height, approximately half the length of
  the shortest side on the top/bottom faces.

* There are rounded corners between the side faces.

* There is a "manufacturer's joint" to join the end-most side faces
  together.

20200831/https://en.wikipedia.org/wiki/Corrugated_fiberboard

----------

## Box Layout Dimensions

First of all, let's compute the corner radius using photo propotions
and our box measurements, on the "19.5 inch wide" face photo.

```
5.20 / 501.40 = 0.01 proportion
Length 19.5 in, so effective corner radius = 0.202 inches
```

This is similar to the half-inch circumference measurements of another
similar sized box that I have.  That is, "circumference" as the length
along one rounded corner.

So, what is the circumference of our rounded corner?

```
0.202 * 2 * 3.14 / 4 = 0.318
```

So, the radius is what you subtract from the box dimensions to get the
dimensions of one box face directly.  The circumference is the joint
length between faces you add into your model.  You don't subtract this
from the vertical length since those edges are scored without
significant rounded corners.

* Corner join lengths: 0.202
* Side face dimensions: 19.096 x 20, 15.096 x 20
* Corner circumference: 0.318

Now, if the desired corner radius was 1/4 inch, the numbers would work
out more nicely.  So, let's simply present some nicer potential
numbers for posterity.

* Corner join lengths: 0.2
* Side face dimensions: 19.1 x 20, 15.1 x 20
* Corner circumference: 0.314

* Corner join lengths: 0.25
* Side face dimensions: 19 x 20, 15 x 20
* Corner circumference: 0.393

Another point to note.  With these dimensions, this means that the
flaps are a little longer than half the length of the shortest face in
the cardboard design.  This is as intended because the total box
dimensions are still the same.

* Flap length: 15.5 / 2 = 7.75

Well, almost... I might recommend adjusting to 7.706 inch tall flaps,
as per the photo measurements.  After testing from printing and
folding a miniature paper model, I can attest that the longer flaps
are a little too long, so please do shorten the top and bottom flaps
accordingly.  After a careful look at the flaps, maybe even a little
shorter would still be better.

Box fusing tab, let's call that 2 inches, I'll have to obtain the
actual measurement later.

----------

## Box Design Layout Max Extents

So, let's determine the maximum physical extents to lay out the
two-dimensional design canvas, erring on the side of over-specifying
the required space to allow for minor adjustments later.

* Height: 20 + 7.75 + 7.75 = 35.5 inches

* Width: 2 + 0.25 + 19.5 + 0.25 + 15.5 + 0.25 + 19.5 + 0.25 + 15.5 =
  73 inches

Now, for the sake of a box design layout, give ourselves one inch
extra space on all 4 sides.

TOTAL PDF LAYOUT DIMENSIONS:

WIDTH: 73 + 1 + 1 = 75 inches
HEIGHT: 35.5 + 1 + 1 = 37.5 inches

----------

## Cardboard Material Specifications

What type of cardboard is used to manufacture this box?  The box
certificate printed on the box provides ample data on this.  Though
the data is clearly visible in the retraced vector drawing, the data
is also copied here for posterity.

PACIFIC SOUTHWEST CONTAINER INC  
MODESTO, CALIFORNIA 95351

BOX CERIFICATE

THIS SINGLE WALL BOX MEETS ALL CONSTRUCTION REQUIREMENTS OF APPLICABLE
FREIGHT CLASSIFICATION.

* BURSTING TEST: 275 LIBS PER SQ INCH
* MIN COMB WT FACINGS: 138 LBS PER M SQ FT
* SIZE LIMIT: 90 INCHES
* GROSS WT LT: 90 LBS

Please note that the given address no longer corresponds to Pacific
Southwest Container's current location, but it cones pretty close.

----------

## Fonts

Apple Garamond font:

20200829/DuckDuckGo apple garamond font  
20200829/https://www.dafont.com/apple-garamond.font

Download directly as follows:

```
curl -L -o apple_garamond.zip 'https://dl.dafont.com/dl/?f=apple_garamond'
```

For miscellaneous sans-serif fonts, I did not quite do as good of a
job in font matching as I could have.  These are the fonts that I
used.

* Real font for `sans-serif` default font alias: DejaVu Sans
* Liberation Sans
* Liberation Sans Narrow

PLEASE NOTE: The last line on the "Keyboard not included * Mouse
included" line is written in Japanese.  Of course it does not use the
same Apple Garamond font, it's much less decorative.  But, point in
hand, these are the characters to use, almost an exact match return
from using Google Translate, compared to what was originally printed
on the box.  Right now the strokes are just directly hand-drawn, I'll
have to hunt around for a better matching font later.

キーボードは含まれていません * マウス付
