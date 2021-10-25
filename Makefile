export LUA_PATH := lib/?.lua;lib/?/init.lua;;
AMALG := amalg.lua
LUACHECK := luacheck
LUAC := luac
SCRIPTS := static-link link-volume
TESTS := example
MODULES := $(SCRIPTS) $(TESTS)
INSTALLDIR ?= /usr/share/wireplumber

BUILD_DIR := build
PREFIX := loader/require.lua
AMALG_FLAGS := --no-argfix -p $(PREFIX)
LUACHECKRC := .luacheckrc
LUACHECK_FLAGS := --config $(LUACHECKRC)

OUTPUTS_SCRIPTS := $(foreach mod,$(SCRIPTS),build/$(mod).lua)
OUTPUTS_TESTS := $(foreach mod,$(TESTS),build/$(mod).lua)
OUTPUTS := $(OUTPUTS_SCRIPTS) $(OUTPUTS_TESTS)
resolvedeps = $(foreach dep,$(1),$(dep) $(if $(DEPENDS_$(dep)),$(call resolvedeps,$(DEPENDS_$(dep))),))
depsof = $(call resolvedeps,$(DEPENDS_$1))
luapath = $(wildcard lib/$(subst .,/,$(1)).lua lib/$(subst .,/,$(1))/init.lua)

DEPENDS_wp.proxy.link := wp.proxy
DEPENDS_scripts.static-link := wp.proxy wp.proxy.link util.table
DEPENDS_scripts.link-volume := wp.proxy wp.proxy.node wp.params util.table

DEPENDS_static-link := scripts.static-link
DEPENDS_link-volume := scripts.link-volume
DEPENDS_example := scripts.static-link scripts.link-volume

export WIREPLUMBER_DEBUG ?= 4

all: $(OUTPUTS_SCRIPTS)

clean:
	rm -f $(OUTPUTS)

install: $(OUTPUTS_SCRIPTS)
	install -Dm0644 -t $(INSTALLDIR)/scripts $^

check: $(OUTPUTS_SCRIPTS)
	$(LUAC) -p $^
	$(LUACHECK) $(LUACHECK_FLAGS) $^

tests: $(OUTPUTS_TESTS)

$(BUILD_DIR)/.keep:
	mkdir -p $(BUILD_DIR)
	touch $(BUILD_DIR)/.keep

$(BUILD_DIR)/%.lua: src/%.lua $(BUILD_DIR)/.keep
	$(AMALG) $(AMALG_FLAGS) -o $@ -s $< $(call depsof,$*)

define modtemplate =
$(BUILD_DIR)/$(1).lua: $(foreach dep,$(call depsof,$(1)),$(call luapath,$(dep)))
endef
$(foreach mod,$(MODULES),$(eval $(call modtemplate,$(mod))))

define testtemplate =
test-$(1): build/$(1).lua
	wpexec $$<
.PHONY: test-$(1)
endef
$(foreach test,$(TESTS),$(eval $(call testtemplate,$(test))))

.PHONY: all clean install check tests
.DELETE_ON_ERROR:
