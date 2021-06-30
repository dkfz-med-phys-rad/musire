BINARIES = create-pc-ply-from-tumor-mhd add-tumor-mhd-into-phantom-mhd create-density-mhd-from-phantom-mhd create-downsampled-tumor-mhd add-ushort-raw-into-second add-float-raw-into-second create-activity-dat-for-total-activity-in-phantom-mhd tilt-mhd mirror-mhd
SOURCES = $(wildcard *.cpp *.h)

CC      = g++
CFLAGS  = -O3 -std=gnu++17 -m64
CPPFLAGS = $(CFLAGS)
LD      = $(CC)
LDFLAGS = -L../lib -lm -m64 -lstdc++fs -L../lib

BACKUP_FILE := ~/backups/musire-tools-$(shell date '+%Y-%m-%d-%H-%M-%S').tgz

.PHONY: clean backup all edit

all: $(BINARIES)

$(BINARIES): %: %.cpp
	$(CC) $(CFLAGS) -o $@ $(LDFLAGS) $<

clean:
	@(rm -rf $(BINARIES))

backup:
	@(echo "Creating $(BACKUP_FILE)")
	@(tar -czf $(BACKUP_FILE) $(SOURCES) makefile )
	@(tar --list -f $(BACKUP_FILE))

edit:
	nvim -p $(SOURCES) makefile

