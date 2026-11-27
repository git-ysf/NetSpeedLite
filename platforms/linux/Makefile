CC      ?= gcc
CFLAGS  ?= -std=c99 -O2 -Wall -Wextra -Wpedantic
LDFLAGS ?= -s
PREFIX  ?= /usr/local
BINDIR  := $(DESTDIR)$(PREFIX)/bin
APPDIR  := $(DESTDIR)$(PREFIX)/share/applications

TARGET  := netspeedlite
SRC     := netspeedlite.c

.PHONY: all debug install uninstall clean size

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

debug:
	$(CC) -std=c99 -g -O0 -Wall -Wextra -Wpedantic -fsanitize=address,undefined -o $(TARGET) $(SRC)

install: $(TARGET)
	install -d "$(BINDIR)"
	install -m 0755 $(TARGET) "$(BINDIR)/$(TARGET)"
	install -d "$(APPDIR)"
	install -m 0644 netspeedlite.desktop "$(APPDIR)/netspeedlite.desktop"

uninstall:
	rm -f "$(BINDIR)/$(TARGET)"
	rm -f "$(APPDIR)/netspeedlite.desktop"

size: $(TARGET)
	ls -lh $(TARGET) && size $(TARGET)

clean:
	rm -f $(TARGET)
