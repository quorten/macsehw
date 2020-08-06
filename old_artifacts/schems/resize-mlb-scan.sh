#! /bin/sh
# Given the input illegible scan of the Macintosh SE Main Logic Board
# Page 1 schematic, apply some image processing magic on it to make it
# somewhat more legible.

# Here's how our image processing operations work.
#
# 1. The original scanned image is monochrome.  Gradation is expressed
#    linearly through the means of error-diffusion half-toning.
#
# 2. To convert to grayscale, we simply convert to 8-bit grayscale and
#    then resize to 80%, using a cubic resize image filtering
#    algorithm.  The resulting 8-bit intensity values will be
#    expressed in a linear sample space.  We then resize by 250% to
#    get a grayscale image, linear intensity samples, that is twice
#    the spatial resolution of the original.
#
#    The second resizing step is mainly to ease looking at zoomed in
#    copies of the image, which you must do almost all the time due to
#    the illegibility of the original.
#
# 3. If the image is displayed directly on sRGB displays, it will
#    appear artificially dark because it is currently using linear
#    intensity samples, but an sRGB display uses a curve
#    (approximately gamma = 2.2) to map the image samples to linear
#    light intensities.  Just leave it this way because the source
#    image is already pretty light to begin with.  The artificial
#    darkening makes the image easier to read.
#
#    To get a gamma-correct image, we would need to apply a `gamma =
#    0.45` curve to the image.  Or, in other words, "gamma-correct" by
#    a factor of `1/0.45 = 2.2`.  Alternatively, we could use the more
#    precise sRGB colorspace conversion function.

set -e # Exit on errors.

# N.B. We use two conversion command lines because I think otherwise
# ImageMagick just replaces the previous resize command with the new
# resize command and would only end up resizing the image once.

convert -depth 8 -resize 80% -filter cubic se_mlb_p1.gif se_mlb_p1_tmp.png
convert -resize 250% -filter cubic se_mlb_p1_tmp.png se_mlb_p1_proc.png
rm se_mlb_p1_tmp.png
