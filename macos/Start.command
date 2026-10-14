#!/bin/zsh
set -eu
cd "${0:A:h}"
exec ./FishGo.app/Contents/MacOS/FishGo --connect
