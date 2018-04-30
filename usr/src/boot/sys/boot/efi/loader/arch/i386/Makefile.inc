
SRCS +=	multiboot_tramp.S \
	start.S \
	bootinfo64.c

OBJS +=	multiboot_tramp.o \
	start.o \
	bootinfo64.o

SRCS +=	nullconsole.c \
	spinconsole.c \
	comconsole.c

OBJS +=	nullconsole.o \
	spinconsole.o \
	comconsole.o
