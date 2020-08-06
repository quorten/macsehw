#! /bin/sh
# Use a shell script to download the scans so that we do not add bloat
# to the repository size that we don't strictly need.  GitHub has
# bandwidth limits, so let's try to keep away from those as much as
# possible.

curl -L -o 'se_mlb_p1.gif' https://museo.freaknet.org/gallery/apple/stuff/mac/andreas.kann/SE_P1.GIF
