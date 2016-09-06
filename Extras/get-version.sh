#!/bin/bash
git describe --dirty --abbrev=4 | sed -e "s/^[^0-9]*//" | tr '[:lower:]' '[:upper:]' | sed -e "s/DIRTY/MOD/g"