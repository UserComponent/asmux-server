ASM     = nasm
LD      = ld
AFLAGS  = -f elf64
LFLAGS  =
OBJECTS = server.o

default: assemble
	$(LD)  $(OBJECTS) $(LFLAGS) -o asmux-server
	rm -f *.o

assemble:
	$(ASM) $(AFLAGS) server.asm

clean:
	rm -f *.o
