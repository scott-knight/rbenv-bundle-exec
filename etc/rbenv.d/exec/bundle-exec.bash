# Skip if already bundling, explicitly disabled, or command is `gem`
[[ -n "$NO_BUNDLE_EXEC" || "$RBENV_COMMAND" == "bundle" || "$RBENV_COMMAND" == "gem" ]] && return

# Skip if bundler isn't available
command -v bundle > /dev/null 2>&1 || return

# Skip if command is in ~/.no_bundle_exec
if [[ -f "$HOME/.no_bundle_exec" ]]; then
  while IFS= read -r skip_cmd || [[ -n "$skip_cmd" ]]; do
    [[ "$RBENV_COMMAND" == "$skip_cmd" ]] && return
  done < "$HOME/.no_bundle_exec"
fi

# Fast path: Bundler already located a Gemfile (env var set by a parent bundle process)
if [[ -z "$BUNDLE_GEMFILE" ]]; then
  # Slow path: walk up the directory tree looking for a Gemfile (max 10 levels)
  dir="$PWD"
  depth=0
  found=0
  while [[ -n "$dir" && $depth -lt 10 ]]; do
    if [[ -f "$dir/Gemfile" ]]; then
      found=1
      break
    fi
    dir="${dir%/*}"
    (( depth++ ))
  done
  [[ $found -eq 0 ]] && return
fi

[[ -n "$DEBUG_RBENV_BUNDLE_EXEC" ]] && echo "bundle exec ${*}" >&2
RBENV_COMMAND="bundle"
RBENV_COMMAND_PATH="bundle"
set -- "bundle" "exec" "${@}"
