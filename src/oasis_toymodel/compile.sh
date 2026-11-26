#!/bin/sh

# Usage: ./compile.sh [clean|no]
#   (none)  : make clean, then make all
#   no      : rebuild without cleaning (make -B all)
#   clean   : make clean only
# Load the modules listed in README.md first, or set PRISM_PATH to another OASIS3-MCT install.

clean=$1       # 1st argument: "clean" = clean only, "no" = build without cleaning

cd "$(dirname "$0")" || exit 1
TARGET=MAIN_cmf_toymodel

if [ "$clean" = "no" ]; then
  echo "*********** oasis_toymodel **********"
  make -B all || exit 1
elif [ "$clean" = "clean" ]; then
  make clean
  exit $?
else
  make clean
  echo "*********** oasis_toymodel **********"
  make all || exit 1
fi

EXE=../$TARGET
if [ -r $EXE ]; then
  echo "Compilation OK!  Executable created: $(cd .. && pwd)/$TARGET"
else
  echo "### ERROR in compile ###"
  echo "Problems during Compilation. Executable not created."
  echo "### ### ### ### ###"
  exit 1
fi
