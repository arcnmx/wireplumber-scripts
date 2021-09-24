PREFIX := lib/require.lua
export LUA_PATH := lib/?.lua;;
AMALG := amalg.lua

OUTPUTS := build/static-link.lua

DEPENDS_static-link := wp params

all: $(OUTPUTS)

clean: $(OUTPUTS)
	rm -f $(OUTPUTS)

install: $(OUTPUTS)
	install -Dm0644 -t $(INSTALLDIR)/scripts $^

check: $(OUTPUTS)
	luac -p $^

build/.keep:
	mkdir -p build
	touch build/.keep

build/%.lua: src/%.lua build/.keep
	$(AMALG) -o $@ -p $(PREFIX) -s $< $(DEPENDS_$*)

.PHONY: clean install check
.DELETE_ON_ERROR:
