#!/usr/bin/env bash
URL="https://github.com/fungos/cr/raw/refs/heads/master/cr/cr.h"
FILE="${URL##*/}"

# Download the release
if [ ! -f "$FILE" ]; then
  echo "Downloading $FILE from $URL ..."
  curl -L "$URL" -o "$FILE"
  echo ""
fi
