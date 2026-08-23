# Optional convenience wrapper for the bilingual YAML resume builder.
RUBY ?= ruby
BUILD := $(RUBY) build.rb

.PHONY: all en zh validate clean

all:
	$(BUILD)

en:
	$(BUILD) --lang en

zh:
	$(BUILD) --lang zh

validate:
	$(BUILD) --validate-only

clean:
	$(RUBY) -e "require 'fileutils'; FileUtils.rm_rf('.build')"
