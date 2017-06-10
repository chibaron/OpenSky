# object files
DRIVER_SRCS   =
HAL_SRCS      = hal_led.c \
				hal_uart.c \
				hal_timeout.c \
				hal_wdt.c \
				hal_clocksource.c \
				hal_spi.c \
				hal_cc25xx.c \
				hal_io.c hal_adc.c \
				hal_storage.c \
				hal_sbus.c \
				hal_ppm.c \
				hal_soft_spi.c \
				hal_soft_serial.c \
				hal_debug.c

ARCH_SRCS    := $(addprefix $(ARCH_DIR)/, $(HAL_SRCS))
ARCH_HEADERS := $(ARCH_SRCS:.c=.h)

BOARD_SRCS   := $(GENERIC_SRCS) \
				$(ARCH_SRCS)

INCLUDE_DIRS := $(INCLUDE_DIRS) \
				$(SRC_DIR) \
				$(ARCH_DIR) \
				$(TARGET_DIR)

# fetch this dir during include
SELF_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

#name of executable
RESULT ?= opensky_$(notdir $(TARGET))

#faster build
MAKEFLAGS+=" "

#opt
CFLAGS += -Os -g

# include path
CFLAGS += -I$(SELF_DIR)

HEADERS := $(BOARD_SRCS:.c=.h)
OBJECTS      = $(BOARD_SRCS:.c=.o)

# Tool path, only override if not set
TOOLROOT ?= /usr/bin

# Tools
CC=$(TOOLROOT)/avr-gcc
LD=$(TOOLROOT)/avr-gcc
AR=$(TOOLROOT)/avr-gcc-ar
AS=$(TOOLROOT)/avr-as
OBJ=$(TOOLROOT)/avr-objcopy
SIZE=$(TOOLROOT)/avr-size
AVRDUDE=$(TOOLROOT)/avrdude

# Search path for standard files
vpath %.c $(SRC_DIR)
vpath %.c $(ARCH_DIR)

# Search path for perpheral library
vpath %.c $(CORE)
vpath %.c $(PERIPH)/src
vpath %.c $(DEVICE)

# Compilation Flags
BOARD_NAME?=atmega328p
BOARD_FLAGS?= -mmcu=$(BOARD_NAME) -DF_CPU=8000000L
SERIAL_PORT?=/dev/tty.usbserial-A50285BI

LDFLAGS+= $(BOARD_FLAGS) -Wl,--gc-sections -Os -g -flto -fuse-linker-plugin -Wall  -Wpedantic -Werror
CFLAGS+= -std=gnu11 -flto -fno-fat-lto-objects $(BOARD_FLAGS)
CFLAGS+= -DBUILD_TARGET=$(TARGET) \
		$(addprefix -I,$(INCLUDE_DIRS))


LINK_OBJS=$(BOARD_SRCS:%.c=%.o)

HEADER_FILES  = $(wildcard $(ARCH_DIR)/*.h)
HEADER_FILES += config.h

# Build executable
board: $(RESULT).elf $(RESULT).hex

$(RESULT).elf: $(LINK_OBJS)
	exit
	@echo $(LINK_OBJS)
	@echo prereqs that are newer than test: $?
	$(LD) $(LDFLAGS) -o $@ $(LINK_OBJS) $(LDLIBS)

%.eep: %.elf
	$(OBJ) -j .eeprom --set-section-flags=.eeprom='alloc,load' \
	       --change-section-lma .eeprom=0 -O ihex $^ $@
	$(SIZE) $^

%.hex: %.elf
	$(OBJ) -O ihex -R .eeprom $^ $@
	$(SIZE) $^


flash: $(RESULT).hex
	$(AVRDUDE) -q -V -p $(BOARD_NAME) \
		-C $(TOOLROOT)/../etc/avrdude.conf \
		-D -c arduino -b 57600 -P $(SERIAL_PORT) \
		-U flash:w:$^:i

# pull in dependencies
# this includes all .d files produced along when building .o.
# On the first build there are not going to be any .d files.
# Hence, ignore include errors with -.
ALL_DEPS := $(patsubst %.c,%.d,$(BOARD_SRCS))
-include $(ALL_DEPS)

# compile and generate dependency info
%.o: %.c $(HEADER_FILES)
	$(CC) -c $(CFLAGS) $< -o $@
	$(CC) -MM -MP $(CFLAGS) $< > $@.d

%.o: %.s
	$(CC) -c $(CFLAGS) $(DEPFLAGS) $< -o $@

clean:
	rm -f *.o *.d *.elf *.hex *.eep
	rm -f $(OBJECTS)

ctags:
	ctags *.c *.h arch/atmega328/*.c arch/atmega328/*.h board/atmega328/*.h

.PHONY: board clean flash debug
