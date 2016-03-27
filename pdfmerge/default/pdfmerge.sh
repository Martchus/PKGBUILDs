#!/bin/sh
if [[ $# == 0 ]]; then
  echo "Usage: pdfmerge output input1 input2 ..."
else
  output="$1"
  shift 1
  gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="$output" "$@"
fi
