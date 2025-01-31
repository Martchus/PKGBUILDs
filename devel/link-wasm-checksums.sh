#!/bin/bash
for f in qt6-*/wasm/*-sha256.txt; do ln -sf "../mingw-w64/${f##*/}" "$f"; done
