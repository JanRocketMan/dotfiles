#!/bin/bash
CURRENT_DIR=$(tmux display -p "#{pane_current_path}")
tmux new-window -a -c "$CURRENT_DIR"
