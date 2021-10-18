export LUA_PATH := lib/?.lua;lib/?/init.lua;;
AMALG := amalg.lua
LUACHECK := luacheck
LUAC := luac
MODULES := static-link link-volume
INSTALLDIR ?= /usr/share/wireplumber

BUILD_DIR := build
PREFIX := loader/require.lua
AMALG_FLAGS := --no-argfix -p $(PREFIX)
LUACHECKRC := .luacheckrc
LUACHECK_FLAGS := --config $(LUACHECKRC)

OUTPUTS := $(foreach mod,$(MODULES),build/$(mod).lua)
depsof = $(foreach dep,$(DEPENDS_$1),$(if $(DEPS_$(dep)),$(DEPS_$(dep)),$(dep)))
luapath = $(wildcard lib/$(subst .,/,$(1)).lua lib/$(subst .,/,$(1))/init.lua)

DEPS_wp.proxy := wp.proxy
DEPS_wp.proxy.link := wp.proxy.link $(DEPS_wp.proxy)

DEPENDS_static-link := wp.proxy wp.proxy.link util.table
DEPENDS_link-volume := wp.proxy wp.proxy.node wp.params util.table

all: $(OUTPUTS)

clean: $(OUTPUTS)
	rm -f $(OUTPUTS)

install: $(OUTPUTS)
	install -Dm0644 -t $(INSTALLDIR)/scripts $^

check: $(OUTPUTS)
	$(LUAC) -p $^
	$(LUACHECK) $(LUACHECK_FLAGS) $^

$(BUILD_DIR)/.keep:
	mkdir -p $(BUILD_DIR)
	touch $(BUILD_DIR)/.keep

$(BUILD_DIR)/%.lua: src/%.lua $(BUILD_DIR)/.keep
	$(AMALG) $(AMALG_FLAGS) -o $@ -s $< $(call depsof,$*)

define modtemplate =
$(BUILD_DIR)/$(1).lua: $(foreach dep,$(call depsof,$(1)),$(call luapath,$(dep)))
endef
$(foreach mod,$(MODULES),$(eval $(call modtemplate,$(mod))))

.PHONY: all clean install check
.DELETE_ON_ERROR:
