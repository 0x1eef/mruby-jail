# Makefile for mruby-jail
#
# Prerequisites:
#   ../mruby    # mruby checkout (sibling directory)
#
# Quick start:
#   make        # build toolchain and run tests
#   make test   # run tests
#   make clean  # clean build artifacts

MRUBY_DIR    ?= ../mruby
BUILD_CONFIG  = build.rb
BUILD_NAME    = mruby-jail
BUILD_DIR     = $(MRUBY_DIR)/build/$(BUILD_NAME)
BUILD_PROFILE ?= test

TOOLCHAIN_BIN  = bin/mruby bin/mrbc bin/mruby-config
TOOLCHAIN_STAMP = tmp/toolchain.$(BUILD_PROFILE).stamp

.PHONY: all test toolchain clean distclean

all: toolchain test

test: toolchain
	ENV=TEST bin/mruby spec/jail_spec.rb

toolchain: $(TOOLCHAIN_STAMP)

$(TOOLCHAIN_STAMP): $(BUILD_CONFIG) mrbgem.rake $(shell find mrblib spec src -type f 2>/dev/null | sort)
	mkdir -p tmp bin
	ruby -C $(MRUBY_DIR) minirake clean 2>/dev/null || true
	BUILD_PROFILE=$(BUILD_PROFILE) ruby -C $(MRUBY_DIR) minirake MRUBY_CONFIG=$$(pwd)/$(BUILD_CONFIG)
	cp -r $(BUILD_DIR)/bin/* bin/
	touch $(TOOLCHAIN_STAMP)

clean:
	rm -f $(TOOLCHAIN_BIN)
	rm -f tmp/toolchain.*.stamp

distclean: clean
	rm -rf $(BUILD_DIR)
