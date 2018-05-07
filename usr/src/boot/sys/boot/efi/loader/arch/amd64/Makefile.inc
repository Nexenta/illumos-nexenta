
SRCS +=	multiboot_tramp.S \
	start.S \
	bootinfo64.c \
	trap.c \
	exc.S

OBJS += multiboot_tramp.o \
	start.o \
	bootinfo64.o \
	trap.o \
	exc.o

SRCS +=	nullconsole.c \
	spinconsole.c \
	comconsole.c

OBJS += nullconsole.o \
	spinconsole.o \
	comconsole.o
