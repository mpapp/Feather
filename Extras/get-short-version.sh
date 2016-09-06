#!/bin/bash
git describe --abbrev=0 | sed -e "s/^[^0-9]*//" | SED -e "s/DIRTY/MOD/g"