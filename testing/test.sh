#!/usr/bin/env bash
set -eu

PLUGIN="${1-static-link}"

wpexec_rs() {
	cargo run --manifest-path ${WIREPLUMBER_RS-../../wireplumber.rs}/examples/Cargo.toml --bin wpexec -- "$@"
}

mkdir -p modules
ln -fs ${CARGO_TARGET_DIR-target}/x86_64-unknown-linux-gnu/debug/libwpscripts_*.so modules/
ln -fs $(nix-build --no-out-link '<nixpkgs>' -A wireplumber)/lib/wireplumber-0.4/lib* modules/

cargo build --manifest-path ../Cargo.toml -p wpscripts-$PLUGIN

export WIREPLUMBER_MODULE_DIR=$PWD/modules
wpexec_rs -t lua-config $PWD/$PLUGIN.lua -p $PLUGIN
