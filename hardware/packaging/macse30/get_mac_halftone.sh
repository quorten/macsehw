#! /bin/sh
# Use a shell script to download a larger PNG image.  GitHub has
# bandwidth limits, so let's try to keep away from those as much as
# possible.

# TODO FIXME: We should use scripting to generate this from the
# original photos, the current image was just hacked together via some
# GUI photo editing.

# NOTE: Processing from original photo:
# Crop to: upper left corner 606,687 size 456x524

curl -L -o mac_halftone.png 'https://drive.google.com/uc?export=download&id=18Nl-1DJkCo8ceyCM3i6Pw9AWOyl8iEVY'
