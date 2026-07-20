CXX     := g++
CC      := gcc
CFLAGS  := -Wall -O2 -Iinclude -I/usr/include -I/usr/local/include
CXXFLAGS:= -Wall -O2 -Iinclude -I/usr/include -I/usr/local/include
LDFLAGS := -lkipr -lm -lz -lpthread -L/usr/lib -L/usr/local/lib

# Find all .c and .cpp files under src/
SRC_C   := $(shell find src -name '*.c')
SRC_CXX := $(shell find src -name '*.cpp')

OBJ_C   := $(patsubst src/%.c,build/%.o,$(SRC_C))
OBJ_CXX := $(patsubst src/%.cpp,build/%.o,$(SRC_CXX))
OBJ     := $(OBJ_C) $(OBJ_CXX)

# Use g++ for linking if there are C++ files
ifeq ($(strip $(SRC_CXX)),)
  LINKER := $(CC)
else
  LINKER := $(CXX)
endif

TARGET  := robot

# Binary name for the KISS bin/ folder (override via: make KISS_BIN=bin/MyProject)
KISS_BIN :=

.PHONY: all clean

all: $(TARGET)
ifdef KISS_BIN
	@mkdir -p $(dir $(KISS_BIN))
	sudo rm -f $(KISS_BIN) || true
	cp $(TARGET) $(KISS_BIN)
	sudo chmod +x $(KISS_BIN)
endif

build/%.o: src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: src/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(TARGET): $(OBJ)
	$(LINKER) $^ -o $@ $(LDFLAGS)

clean:
	rm -rf build $(TARGET)
