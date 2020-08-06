#! /bin/sh
# Use a shell script to download the photos so that we do not add
# bloat to the repository size that we don't strictly need.  GitHub
# has bandwidth limits, so let's try to keep away from those as much
# as possible.

curl -L https://upload.wikimedia.org/wikipedia/commons/6/65/Apple_Macintosh_SE_Main_PCB.jpg -o wikipedia_se_mlb.jpg
curl -L https://recapamac.com.au/wp-content/uploads/2019/08/mac_se_logic.jpg -o recapamac_se_mlb.jpg
