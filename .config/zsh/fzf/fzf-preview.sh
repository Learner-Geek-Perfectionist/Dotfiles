#!/usr/bin/env bash
#
# The purpose of this script is to demonstrate how to preview a file or text
# content in the preview window of fzf.
#
# Dependencies:
# - https://github.com/sharkdp/bat
# - https://github.com/hpjansson/chafa
# - https://iterm2.com/utilities/imgcat

if [[ $# -ne 1 ]]; then
  >&2 echo "usage: $0 FILENAME_OR_TEXT"
  exit 1
fi

file=${1/#\~\//$HOME/}

# Check if the argument is an existing file
if [[ ! -e "$file" ]]; then
  # Treat the argument as text content
  if command -v batcat > /dev/null; then
    batname="batcat"
  elif command -v bat > /dev/null; then
    batname="bat"
  else
    echo "$1"
    exit
  fi
  echo "$1" | ${batname} --style="${BAT_STYLE:-numbers}" --color=always --pager=never -
  exit
fi

type=$(file --dereference --mime -- "$file")

if [[ ! $type =~ image/ ]]; then
  if [[ $type =~ =binary ]]; then
    file "$1"
    exit
  fi

  # Sometimes bat is installed as batcat.
  if command -v batcat > /dev/null; then
    batname="batcat"
  elif command -v bat > /dev/null; then
    batname="bat"
  else
    cat "$1"
    exit
  fi

  ${batname} --style="${BAT_STYLE:-numbers}" --color=always --pager=never -- "$file"
  exit
fi

dim=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}
if [[ $dim = x ]]; then
  dim=$(stty size < /dev/tty | awk '{print $2 "x" $1}')
elif ! [[ $KITTY_WINDOW_ID ]] && (( FZF_PREVIEW_TOP + FZF_PREVIEW_LINES == $(stty size < /dev/tty | awk '{print $1}') )); then
  # Avoid scrolling issue when the Sixel image touches the bottom of the screen
  # * https://github.com/junegunn/fzf/issues/2544
  dim=${FZF_PREVIEW_COLUMNS}x$((FZF_PREVIEW_LINES - 1))
fi

# 1. Use kitty icat on kitty terminal
if [[ $KITTY_WINDOW_ID ]]; then
  kitty icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --place="$dim@0x0" "$file" | sed '$d' | sed $'$s/$/\e[m/'

# 2. Use chafa with Sixel output
elif command -v chafa > /dev/null; then
  chafa -s "$dim" "$file"
  echo

# 3. If chafa is not found but imgcat is available, use it on iTerm2
elif command -v imgcat > /dev/null; then
  imgcat -W "${dim%%x*}" -H "${dim##*x}" "$file"

# 4. Cannot find any suitable method to preview the image
else
  echo "No suitable method to preview the image."
  exit 1
fi