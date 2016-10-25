# uncomment to be verbose
#SHELL:=/usr/bin/env bash -x

# The name of your project (used to name the compiled .hex file)
TARGET = $(notdir $(CURDIR))

# The teensy version to use, 30, 31, or LC
TEENSY = 31

# What version of Teensduino do we have?
TEENSYDUINO_VERSION = 130

# Set to 24000000, 48000000, or 96000000 to set CPU core speed
TEENSY_CORE_SPEED = 96000000

# Some libraries will require this to be defined
# If you define this, you will break the default main.cpp
ARDUINO = 10611

# configurable options
OPTIONS = -DUSB_MIDI_AUDIO_SERIAL -DLAYOUT_US_ENGLISH

# directory to build in
BUILDDIR = $(abspath $(CURDIR)/build)

#************************************************************************
# Location of Teensyduino utilities, Toolchain, and Arduino Libraries.
# To use this makefile without Arduino, copy the resources from these
# locations and edit the pathnames.  The rest of Arduino is not needed.
#************************************************************************

# path location for Teensy Loader, teensy_post_compile and teensy_reboot
TOOLSPATH = $(CURDIR)/tools

ifeq ($(OS),Windows_NT)
	$(error What is Win Dose?)
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Darwin)
		TOOLSPATH = /Applications/Arduino.app/Contents/Java/hardware/tools/
	endif
endif

# path location for Teensy 3 core
#COREPATH = /Applications/Arduino.app/Contents/Java/hardware/teensy/avr/cores/teensy3/
COREPATH = $(abspath $(CURDIR)/cores/teensy3/)

# path location for Arduino libraries
LIBRARYPATH = libraries

# path location for the arm-none-eabi compiler
COMPILERPATH = $(TOOLSPATH)/arm/bin

#************************************************************************
# Settings below this point usually do not need to be edited
#************************************************************************

# CPPFLAGS = compiler options for C and C++
CPPFLAGS = -Wall -g -Os -mthumb -ffunction-sections -fdata-sections -nostdlib -MMD $(OPTIONS) -DTEENSYDUINO=$(TEENSYDUINO_VERSION) -DF_CPU=$(TEENSY_CORE_SPEED) -Isrc -I$(COREPATH)

# compiler options for C++ only
CXXFLAGS = -std=gnu++0x -felide-constructors -fno-exceptions -fno-rtti

# compiler options for C only
CFLAGS =

# linker options
LDFLAGS = -Os -Wl,--gc-sections,--relax,--defsym=__rtc_localtime=0 --specs=nano.specs -mthumb

# additional libraries to link
LIBS = -lm

# compiler options specific to teensy version
ifeq ($(TEENSY), 30)
	MMCU = mk20dx128
	CPPFLAGS += -D__MK20DX128__ -mcpu=cortex-m4
	LDSCRIPT = $(COREPATH)/mk20dx128.ld
	LDFLAGS += -mcpu=cortex-m4 -T$(LDSCRIPT)
else
	ifeq ($(TEENSY), 31)
		MMCU = mk20dx256
		CPPFLAGS += -D__MK20DX256__ -mcpu=cortex-m4
		LDSCRIPT = $(COREPATH)/mk20dx256.ld
		LDFLAGS += -mcpu=cortex-m4 -T$(LDSCRIPT)
		LIBS += -larm_cortexM4l_math
	else
		ifeq ($(TEENSY), LC)
			MMCU = mkl26z64
			CPPFLAGS += -D__MKL26Z64__ -mcpu=cortex-m0plus
			LDSCRIPT = $(COREPATH)/mkl26z64.ld
			LDFLAGS += -mcpu=cortex-m0plus -T$(LDSCRIPT)
			LIBS += -larm_cortexM0l_math
		else
			$(error Invalid setting for TEENSY)
		endif
	endif
endif

# set arduino define if given
ifdef ARDUINO
	CPPFLAGS += -DARDUINO=$(ARDUINO)
else
	CPPFLAGS += -DUSING_MAKEFILE
endif

# names for the compiler programs
CC = $(abspath $(COMPILERPATH))/arm-none-eabi-gcc
CXX = $(abspath $(COMPILERPATH))/arm-none-eabi-g++
OBJCOPY = $(abspath $(COMPILERPATH))/arm-none-eabi-objcopy
SIZE = $(abspath $(COMPILERPATH))/arm-none-eabi-size

# Make does not offer a recursive wildcard function, so here's one:
rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

# automatically create lists of the sources and objects
LC_FILES := $(wildcard $(LIBRARYPATH)/*/*.c) $(shell find libraries/*/{src,lib,utility}/ -name '*.c' 2> /dev/null)
LS_FILES := $(wildcard $(LIBRARYPATH)/*/*.S) $(shell find libraries/*/{src,lib,utility}/ -name '*.S' 2> /dev/null)
LCPP_FILES := $(wildcard $(LIBRARYPATH)/*/*.cpp) $(shell find libraries/*/{src,lib,utility}/ -name '*.cpp' 2> /dev/null)
TC_FILES := $(wildcard $(COREPATH)/*.c)
TCPP_FILES := $(filter-out $(COREPATH)/main.cpp, $(wildcard $(COREPATH)/*.cpp))
C_FILES := $(wildcard src/*.c)
CPP_FILES := $(wildcard src/*.cpp)
INO_FILES := $(wildcard src/*.ino)

# include paths for libraries
L_INC := $(foreach lib,$(filter %/, $(wildcard $(LIBRARYPATH)/*/)), -I$(lib)) $(foreach lib,$(filter %/, $(wildcard $(LIBRARYPATH)/*/*/)), -I$(lib))

SOURCES := $(C_FILES:.c=.o) $(CPP_FILES:.cpp=.o) $(INO_FILES:.ino=.o) $(TC_FILES:.c=.o) $(TCPP_FILES:.cpp=.o) $(LC_FILES:.c=.o) $(LS_FILES:.S=.o) $(LCPP_FILES:.cpp=.o)
OBJS := $(foreach src,$(SOURCES), $(BUILDDIR)/$(src))

all: hex

build: $(TARGET).elf

hex: $(TARGET).hex

post_compile: $(TARGET).hex
	@$(abspath $(TOOLSPATH))/teensy_post_compile -file="$(basename $<)" -path=$(CURDIR) -tools="$(abspath $(TOOLSPATH))"

reboot:
	@-$(abspath $(TOOLSPATH))/teensy_reboot

upload: post_compile reboot

upload-cli: $(TARGET).hex
	teensy_loader_cli -mmcu=$(MMCU) -v -w "$<"

$(BUILDDIR)/%.o: %.c
	@echo "[CC]\t$<"
	@mkdir -p "$(dir $@)"
	@$(CC) $(CPPFLAGS) $(CFLAGS) $(L_INC) -o "$@" -c "$<"

$(BUILDDIR)/%.o: %.S
	@echo "[CC]\t$<"
	@mkdir -p "$(dir $@)"
	@$(CC) -x assembler-with-cpp $(CPPFLAGS) $(CFLAGS) $(L_INC) -o "$@" -c "$<"

$(BUILDDIR)/%.o: %.cpp
	@echo "[CXX]\t$<"
	@mkdir -p "$(dir $@)"
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(L_INC) -o "$@" -c "$<"

$(BUILDDIR)/%.o: %.ino
	@echo "[CXX]\t$<"
	@mkdir -p "$(dir $@)"
	@$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(L_INC) -o "$@" -x c++ -include Arduino.h -c "$<"

$(TARGET).elf: $(OBJS) $(LDSCRIPT)
	@echo "[LD]\t$@"
	@$(CC) $(LDFLAGS) -o "$@" $(OBJS) $(LIBS)

%.hex: %.elf
	@echo "[HEX]\t$@"
	@$(SIZE) "$<"
	@$(OBJCOPY) -O ihex -R .eeprom -R .fuse -R .lock -R .signature "$<" "$@"

# compiler generated dependency info
-include $(OBJS:.o=.d)

clean:
	@echo Cleaning...
	@rm -rf "$(BUILDDIR)"
	@rm -f "$(TARGET).elf" "$(TARGET).hex"
