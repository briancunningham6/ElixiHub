#!/bin/sh

# # Sets and enables heart (recommended only in daemon mode)
# case $RELEASE_COMMAND in
#   daemon*)
#     HEART_COMMAND="$RELEASE_ROOT/bin/$RELEASE_NAME $RELEASE_COMMAND"
#     export HEART_COMMAND
#     export ELIXIR_ERL_OPTIONS="-heart"
#     ;;
#   *)
#     ;;
# esac

# # Set the release to load code on demand (interactive) instead of preloading (embedded).
# export RELEASE_MODE=interactive

# # Set the release to work across nodes.
# # RELEASE_DISTRIBUTION must be "sname" (local), "name" (distributed) or "none".
# export RELEASE_DISTRIBUTION=name
# export RELEASE_NODE=tasks_app
