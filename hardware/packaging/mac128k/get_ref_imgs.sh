#! /bin/sh
# Use a shell script to download a larger PNG image.  GitHub has
# bandwidth limits, so let's try to keep away from those as much as
# possible.

# Get the Macintosh 128k box reference images, transformed from angled
# photos sourced from a probably now-expired Ebay listing.

curl -L -o front_face.png 'https://drive.google.com/uc?export=download&id=1T-Mb_VPAsTLAOTtTWOvSsjf4FuSHZDkA'
curl -L -o side_face.png 'https://drive.google.com/uc?export=download&id=11inXjFEUjz548vJmjLY5IQ_QweclYqRE'
