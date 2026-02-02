KINDLE_CROSS_FILE ?= $(HOME)/x-tools/arm-kindlehf-linux-gnueabihf/meson-crosscompile.txt

.PHONY: all local kindle clean install

all: kindle

local: build_local/bvg-kindle

kindle: build_kindle/bvg-kindle

build_local/bvg-kindle: $(wildcard src/*.cpp src/*.h) meson.build
	@if [ ! -d build_local ]; then meson setup build_local; fi
	meson compile -C build_local

build_kindle/bvg-kindle: $(wildcard src/*.cpp src/*.h) meson.build
	@if [ ! -d build_kindle ]; then meson setup --cross-file $(KINDLE_CROSS_FILE) build_kindle; fi
	meson compile -C build_kindle

clean:
	rm -rf build_local build_kindle

install: build_kindle/bvg-kindle
	@echo "Copy to Kindle via USB:"
	@echo "  cp build_kindle/bvg-kindle /Volumes/Kindle/extensions/bvg/"
	@echo "  cp extensions/bvg/* /Volumes/Kindle/extensions/bvg/"
