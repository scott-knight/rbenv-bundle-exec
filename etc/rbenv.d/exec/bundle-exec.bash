# rbenv-bundle-exec
# rbenv exec hook.

# When a Ruby executable is launched from inside a project with a Gemfile,
# rewrite the command from:
#   sidekiq
# to:
#   bundle exec sidekiq

# This keeps rbenv/rbenv-gemset from loading executables outside the app's
# Bundler context.

# rbenv sets RBENV_COMMAND to the shim command being executed.
# If it is missing, we are not in the expected hook context.
command_name="${RBENV_COMMAND-}"

# Never wrap Bundler itself, RubyGems, or low-level Ruby commands.
# Those commands are often used to manage/debug the environment rather than
# run app dependencies.
case "$command_name" in
  ""|bundle|gem|ruby|irb|erb|ri|rdoc)
    return 0
    ;;
esac

# Per-command escape hatch:
#   NO_BUNDLE_EXEC=1 sidekiq
[[ -n "${NO_BUNDLE_EXEC-}" ]] && return 0

# Optional persistent skip-list. One command per line.
#   echo rubocop >> ~/.no_bundle_exec
# Blank lines and comments are ignored.
skip_file="${HOME-}/.no_bundle_exec"
if [[ -n "${HOME-}" && -f "$skip_file" ]]; then
  while IFS= read -r skipped_command || [[ -n "$skipped_command" ]]; do
    case "$skipped_command" in
      ""|\#*) continue ;;
      "$command_name") return 0 ;;
    esac
  done < "$skip_file"
fi

# If Bundler is not available, leave the command alone.
# `command -v` is a shell builtin; no external lookup helper is needed.
command -v bundle > /dev/null 2>&1 || return 0

# If a parent process already selected a bundle, respect it as long as it still
# points to a real Gemfile.
gemfile="${BUNDLE_GEMFILE-}"

# Otherwise, find the nearest Gemfile by walking upward from the current
# directory. Nearest wins, so nested Ruby projects work correctly.
if [[ -z "$gemfile" || ! -f "$gemfile" ]]; then
  gemfile=""
  directory="${PWD-}"
  depth=0

  # Bound the search so accidental deep paths never cause excessive work.
  while [[ -n "$directory" && "$depth" -lt 20 ]]; do
    if [[ -f "$directory/Gemfile" ]]; then
      gemfile="$directory/Gemfile"
      break
    fi

    # Stop at filesystem root.
    [[ "$directory" == "/" ]] && break

    # Move one directory up without calling dirname.
    parent="${directory%/*}"
    [[ "$parent" == "$directory" ]] && break

    directory="$parent"
    depth=$((depth + 1))
  done
fi

# No Gemfile means this is not a Bundler project; leave the command alone.
[[ -z "$gemfile" ]] && return 0

# Tell Bundler exactly which Gemfile to use. This avoids ambiguity when rbenv,
# default gems, and gemsets all have overlapping gems installed.
export BUNDLE_GEMFILE="$gemfile"

# Optional debug output:
#   DEBUG_RBENV_BUNDLE_EXEC=1 sidekiq
[[ -n "${DEBUG_RBENV_BUNDLE_EXEC-}" ]] && echo "bundle exec ${*}" >&2

# Rewrite the rbenv command to invoke Bundler, preserving the original command
# and arguments after `bundle exec`.
RBENV_COMMAND="bundle"
RBENV_COMMAND_PATH="bundle"
set -- "bundle" "exec" "$@"

# Keep later hooks in the same rbenv exec process tidy.
unset command_name skip_file skipped_command
unset gemfile directory depth parent
