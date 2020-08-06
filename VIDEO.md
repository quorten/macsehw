# Macintosh SE Internal CRT Replacement

Got a Macintosh SE with a non-functional CRT?  No worries, there is
actually an easy workaround to get video on your Macintosh SE!

The CRT is controlled by 3 digital output signals:

* `VIDOUT`
* `*HSYNC`
* `*VSYNC`

These are all 5V logic signals.  Therefore, they can be packed up into
a DB-9 connector for TTL or ECL video.  Commercially available flat
panel displays are avaiable with adapter electronics that can accept
TTL or ECL video, since these apparently became very popular in
specialized industrial equipment.  Once you've got your monitor and
connectors all set up, you should be good to go.

* Visited 2020-08-06:
  https://allpinouts.org/pinouts/connectors/computer_video/ecl-video/
* Visited 2020-08-06:
  https://allpinouts.org/pinouts/connectors/computer_video/monochrome-ttl/

It might be relevant that ECL stands for "Emitter Coupled Logic" in
other contexts, here is a source for reference.

* Visited 2020-08-06:
  https://technobyte.org/logic-families-ttl-cmos-ecl-bicmos-difference/
