#!/bin/bash
if [[ $1 == "vertical" ]]; then
  SPLIT_FLAG="-v"
else
  SPLIT_FLAG="-h"
fi
CURRENT_DIR=$(tmux display -p "#{pane_current_path}")
tmux split-window $SPLIT_FLAG -c "$CURRENT_DIR"
