# rbenv-bundle-exec
# rbenv exec hook: run project gem executables through `bundle exec`.

command_name="${RBENV_COMMAND-}"

case "$command_name" in
  ""|bundle|gem|ruby|irb|erb|ri|rdoc)
    return 0
    ;;
esac

[[ -n "${NO_BUNDLE_EXEC-}" ]] && return 0

skip_file="${HOME-}/.no_bundle_exec"
if [[ -n "${HOME-}" && -f "$skip_file" ]]; then
  while IFS= read -r skipped_command || [[ -n "$skipped_command" ]]; do
    case "$skipped_command" in
      ""|\#*) continue ;;
      "$command_name") return 0 ;;
    esac
  done < "$skip_file"
fi

command -v bundle > /dev/null 2>&1 || return 0

gemfile="${BUNDLE_GEMFILE-}"
if [[ -z "$gemfile" || ! -f "$gemfile" ]]; then
  gemfile=""
  directory="${PWD-}"
  depth=0

  while [[ -n "$directory" && "$depth" -lt 20 ]]; do
    if [[ -f "$directory/Gemfile" ]]; then
      gemfile="$directory/Gemfile"
      break
    fi

    [[ "$directory" == "/" ]] && break

    parent="${directory%/*}"
    [[ "$parent" == "$directory" ]] && break

    directory="$parent"
    depth=$((depth + 1))
  done
fi

[[ -z "$gemfile" ]] && return 0

export BUNDLE_GEMFILE="$gemfile"

[[ -n "${DEBUG_RBENV_BUNDLE_EXEC-}" ]] && echo "bundle exec ${*}" >&2

RBENV_COMMAND="bundle"
RBENV_COMMAND_PATH="bundle"
set -- "bundle" "exec" "$@"

unset command_name skip_file skipped_command
unset gemfile directory depth parent
