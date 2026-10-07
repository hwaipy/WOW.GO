#!/bin/zsh
set -eu
cd "${0:A:h}"
exec ./WowGo.app/Contents/MacOS/WowGo --connect
