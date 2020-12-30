# GLU

The GLU chip is a Programmable Array Logic (PAL) chip used to
facilitate I/O logic and the like.  In particular, it is a PAL16L8.
The equation list and fusemap that can be used to program a modern
ATF16V8 chip is contained here.

The design file is in the CUPL programming language, named `glu.pld`.
It was created by reading the GLU chip as a ROM, dumping it, and
analyzing the output to create simplified logic equations.

The generated fuse map is included in the repository for convenience,
named `glu.jed`.

## Credits

Kai Robinson dumped the actual GLU contents, read it as a 27C020.  Rob
Taylor provided the proper PAL dumper board.  Porchy from
jammarcade.net helped analyze this and converted it into a fuse map
proper.
