#!/bin/bash

CURRENT_DIR=$(tmux display -p "#{pane_current_path}")
DOTDIRS=$(find "$CURRENT_DIR" -maxdepth 1 -type d -name '.*')

COMMANDS="cd $CURRENT_DIR"
for dir in $DOTDIRS; do
  if [ -f "$dir/pyvenv.cfg" ]; then
    COMMANDS+=" && source ${dir}/bin/activate"
  fi
done
COMMANDS+=" && bash -i"

tmux new-window "$COMMANDS"
