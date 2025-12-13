AS=xa
ASFLAGS=-C	# Generate code for the original 6502, no CMOS extensions.

MONITOR=monitor.bin
ROMFILE=rom.image
PAGEDFILE=paged.image

#Not currently built here, but we can use them as prebuilt binaries
BASIC=basic.bin
KRUSADER=krusader.bin

%.bin: %.s
	@echo "[ $@ ]"
	${AS} ${ASFLAGS} -o $@ $<

all:	clean ${MONITOR} ${KRUSADER} ${BASIC}
	@echo "Built tools in ${shell pwd}"

load-krusader:
	make ASFLAGS="${ASFLAGS} -DEXKRUSADER"

load-basic:
	make ASFLAGS="${ASFLAGS} -DEXBASIC"

#Some rules for building images.  We use 256-byte blocks.
%.image:
	dd if=/dev/zero of=$@ bs=256 count=32
#The monitor is at the top of the memory space, which is 1 block from the
#  end of the image, in a conventional, modern Apple replica.
add-monitor: ${ROMFILE} ${MONITOR}
	dd if=${MONITOR} of=${ROMFILE} bs=256 seek=31
#Krusader goes 4k from the top, generally, which is half-way into our 8K image.
add-krusader:  ${ROMFILE} ${KRUSADER}
	dd if=${KRUSADER} of=${ROMFILE} bs=256 seek=16
# ... and BASIC is at the bottom of the ROM space, 8K from the top of the map.
add-basic:  ${ROMFILE} ${BASIC}
	dd if=${BASIC} of=${ROMFILE} bs=256

#This will be a normal 8K ROM image.  If you disable the mini-monitor in 
# Krusader, you will want to add-monitor on the end of this.
image-monitor: clean clean-rom all ${ROMFILE} add-basic add-krusader
#This one will boot BASIC.
image-basic: clean clean-rom load-basic ${ROMFILE} add-basic add-krusader
#This one uses the less heavily modified version of the monitor, and excludes
# Krusader from the build.
image-basiconly: clean clean-rom load-basic add-basic add-monitor
#This one will load Krusader.
image-krusader: clean clean-rom load-krusader ${ROMFILE} add-basic add-krusader add-monitor

new-page: rom.image
	@echo "Adding image to ${PAGEDFILE}"
	cat ${ROMFILE} >> ${PAGEDFILE}

clean:
	@echo "Cleaning in ${shell pwd}"
	$(RM) ${MONITOR} ${KRUSADER} ${BASIC}

clean-rom:
	@echo "Cleaning ROM image in ${shell pwd}"
	$(RM) ${ROMFILE}

clean-paged:
	@echo "Cleaning paged image in ${shell pwd}"
	$(RM) ${PAGEDFILE}

dist: clean clean-rom clean-paged


