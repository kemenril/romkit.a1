# romkit.a1
Most everything you need to build a new ROM image for your Apple 1 or clone system


### What is it

I've recently finished up some RC6502 Apple 1 compatible systems.  Upon building them, I noticed that, though most of the code used in the ROMs on these systems is thought to be in the public domain, and assembly source is available even for the old Woz monitor and Apple BASIC (which were likely written in machine code), getting a full set of source code that will actually build into a good binary on your system is not easy.  Some of what's available builds on on cc65, but cc65 isn't as commonly distributed as it probably should be.  some of it won't compile anywhere, so far as i can tell.  This is an attempt to rectify that problem; to produce a unified set of source files, which will build with only *xa* and *make*.  It's not at all well-tested so far, but it's beginning to look like it might work.  The repository contains the following:

   * **monitor.s**  Assembly source code for the Woz monitor, based on a disassembly by San Bergmans, but ported to build on the *xa* cross-assembler, and including a small **AUTORUN** hack to automatically load something other than the monitor shell after the PIA is initialized.
   * **basic.s**  Assembly source code for the old Apple BASIC interpreter, ported to build under *xa*
   * **krusader.s**  The 6502 version of Krusader 1.3, ported to build under *xa*
   * **Makefile**  contains some rules for building binary code from the source, and also for building 8K ROM images, and larger paged images

### Requirements

The requirements are minimal.  You'll want the *xa* 6502 cross-assembler on you Unix box (or if you've got it on your Atari ST or Amiga, that might work too), and probably *make*.  The rules that make ROM images from the resulting binaries use *dd* and *cat* as well.

### Usage

Take a look at the sources and the Makefile to get a feel for how things work.  Here's an example session which tries to build a 32K paged ROM image in which the first two pages are the usual 8K combination of BASIC and Krusader.  The third will use the *AUTORUN* feature to start in BASIC, and the fourth will start in Krusader.

```shell
[romkit.a1]$ ls
basic.s  krusader.s  Makefile  monitor.s
[romkit.a1]$ make image-monitor
Cleaning in romkit.a1
rm -f monitor.bin krusader.bin basic.bin
Cleaning ROM image in romkit.a1
rm -f rom.image
[ monitor.bin ]
xa -C	 -o monitor.bin monitor.s
[ krusader.bin ]
xa -C	 -o krusader.bin krusader.s
[ basic.bin ]
xa -C	 -o basic.bin basic.s
Built tools in romkit.a1
dd if=/dev/zero of=rom.image bs=256 count=32
32+0 records in
32+0 records out
8192 bytes (8.2 kB, 8.0 KiB) copied, 0.000265505 s, 30.9 MB/s
dd if=basic.bin of=rom.image bs=256
16+0 records in
16+0 records out
4096 bytes (4.1 kB, 4.0 KiB) copied, 0.000106787 s, 38.4 MB/s
dd if=krusader.bin of=rom.image bs=256 seek=16
16+1 records in
16+1 records out
4097 bytes (4.1 kB, 4.0 KiB) copied, 0.000115808 s, 35.4 MB/s
```

Now we have a few things which might be written directly to ROM.  *monitor.bin* is the Woz monitor image, which could go in a 256-byte ROM on an original Apple 1 or an extremely faithful replica.  *krusader.bin* is a 4K image, including *krusader* and Ken's modified version of the Woz monitor.  *rom.image* is an 8K image with BASIC in the lower 4K, and Krusader on top.  Continuing, we add this a couple of times to a paged ROM image.

```shell
[romkit.a1]$ make new-page
Adding image to paged.image
cat rom.image >> paged.image
[romkit.a1]$ make new-page
Adding image to paged.image
cat rom.image >> paged.image
```

Now we finish up by adding one 8K image intended to auto-boot BASIC, and one to run Krusader.

```shell
[romkit.a1]$ make image-basic
Cleaning in romkit.a1
rm -f monitor.bin krusader.bin basic.bin
Cleaning ROM image in romkit.a1
rm -f rom.image
make ASFLAGS="-C	 -DEXBASIC"
make[1]: Entering directory 'romkit.a1'
Cleaning in romkit.a1
rm -f monitor.bin krusader.bin basic.bin
[ monitor.bin ]
xa -C	 -DEXBASIC -o monitor.bin monitor.s
[ krusader.bin ]
xa -C	 -DEXBASIC -o krusader.bin krusader.s
[ basic.bin ]
xa -C	 -DEXBASIC -o basic.bin basic.s
Built tools in romkit.a1
make[1]: Leaving directory 'romkit.a1'
dd if=/dev/zero of=rom.image bs=256 count=32
32+0 records in
32+0 records out
8192 bytes (8.2 kB, 8.0 KiB) copied, 0.000573407 s, 14.3 MB/s
dd if=basic.bin of=rom.image bs=256
16+0 records in
16+0 records out
4096 bytes (4.1 kB, 4.0 KiB) copied, 0.000594767 s, 6.9 MB/s
dd if=krusader.bin of=rom.image bs=256 seek=16
16+0 records in
16+0 records out
4096 bytes (4.1 kB, 4.0 KiB) copied, 0.000417662 s, 9.8 MB/s
[romkit.a1]$ make new-page
Adding image to paged.image
cat rom.image >> paged.image
[romkit.a1]$ make image-krusader
Cleaning in romkit.a1
rm -f monitor.bin krusader.bin basic.bin
Cleaning ROM image in romkit.a1
rm -f rom.image
make ASFLAGS="-C	 -DEXKRUSADER"
make[1]: Entering directory 'romkit.a1'
Cleaning in romkit.a1
rm -f monitor.bin krusader.bin basic.bin
[ monitor.bin ]
xa -C	 -DEXKRUSADER -o monitor.bin monitor.s
[ krusader.bin ]
xa -C	 -DEXKRUSADER -o krusader.bin krusader.s
[ basic.bin ]
xa -C	 -DEXKRUSADER -o basic.bin basic.s
Built tools in romkit.a1
make[1]: Leaving directory 'romkit.a1'
dd if=/dev/zero of=rom.image bs=256 count=32
32+0 records in
32+0 records out
8192 bytes (8.2 kB, 8.0 KiB) copied, 0.00011752 s, 69.7 MB/s
dd if=basic.bin of=rom.image bs=256
16+0 records in
16+0 records out
4096 bytes (4.1 kB, 4.0 KiB) copied, 0.000112893 s, 36.3 MB/s
dd if=krusader.bin of=rom.image bs=256 seek=16
16+0 records in
16+0 records out
4096 bytes (4.1 kB, 4.0 KiB) copied, 8.8707e-05 s, 46.2 MB/s
dd if=monitor.bin of=rom.image bs=256 seek=31
1+0 records in
1+0 records out
256 bytes copied, 5.2498e-05 s, 4.9 MB/s
[romkit.a1]$ make new-page
Adding image to paged.image
cat rom.image >> paged.image
[romkit.a1]$ ls
basic.bin  krusader.bin  Makefile     monitor.s    rom.image
basic.s    krusader.s    monitor.bin  paged.image
[romkit.a1]$
```


