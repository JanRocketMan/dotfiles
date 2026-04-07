#!/bin/bash
CURRENT_DIR=$(tmux display -p "#{pane_current_path}")
tmux new-window -c "$CURRENT_DIR"
