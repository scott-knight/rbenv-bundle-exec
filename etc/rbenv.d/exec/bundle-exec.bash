# rbenv-bundle-exec
# rbenv exec hook: automatically runs gem executables through `bundle exec`
# when invoked from inside a Bundler project.
#
# Escape hatches:
#   NO_BUNDLE_EXEC=1 sidekiq
#   echo sidekiq >> ~/.no_bundle_exec

_rbe_cleanup() {
  unset _rbe_command
  unset _rbe_skip_file _rbe_skip_command
  unset _rbe_pwd _rbe_dir _rbe_parent _rbe_depth _rbe_gemfile
  unset -f _rbe_cleanup
}

_rbe_command="${RBENV_COMMAND-}"

if [[ -z "$_rbe_command" ]]; then
  _rbe_cleanup
  return 0
fi

case "$_rbe_command" in
  bundle|gem|ruby|irb|erb|ri|rdoc)
    _rbe_cleanup
    return 0
    ;;
esac

if [[ -n "${NO_BUNDLE_EXEC-}" ]]; then
  _rbe_cleanup
  return 0
fi

_rbe_skip_file="${HOME-}/.no_bundle_exec"
if [[ -n "${HOME-}" && -f "$_rbe_skip_file" ]]; then
  while IFS= read -r _rbe_skip_command || [[ -n "$_rbe_skip_command" ]]; do
    case "$_rbe_skip_command" in
      ""|\#*) continue ;;
    esac

    if [[ "$_rbe_command" == "$_rbe_skip_command" ]]; then
      _rbe_cleanup
      return 0
    fi
  done < "$_rbe_skip_file"
fi

if ! command -v bundle > /dev/null 2>&1; then
  _rbe_cleanup
  return 0
fi

# If the caller explicitly supplied a valid bundle, honor it.
# If it is stale, ignore it and find the nearest Gemfile normally.
if [[ -n "${BUNDLE_GEMFILE-}" && -f "$BUNDLE_GEMFILE" ]]; then
  _rbe_gemfile="$BUNDLE_GEMFILE"
else
  unset BUNDLE_GEMFILE

  _rbe_pwd="${PWD-}"
  if [[ -z "$_rbe_pwd" ]]; then
    _rbe_cleanup
    return 0
  fi

  _rbe_dir="$_rbe_pwd"
  _rbe_depth=0
  _rbe_gemfile=""

  while [[ -n "$_rbe_dir" && "$_rbe_depth" -lt 20 ]]; do
    if [[ -f "$_rbe_dir/Gemfile" ]]; then
      _rbe_gemfile="$_rbe_dir/Gemfile"
      break
    fi

    [[ "$_rbe_dir" == "/" ]] && break

    _rbe_parent="${_rbe_dir%/*}"
    [[ "$_rbe_parent" == "$_rbe_dir" ]] && break

    _rbe_dir="$_rbe_parent"
    _rbe_depth=$(( _rbe_depth + 1 ))
  done
fi

if [[ -z "$_rbe_gemfile" ]]; then
  _rbe_cleanup
  return 0
fi

export BUNDLE_GEMFILE="$_rbe_gemfile"

[[ -n "${DEBUG_RBENV_BUNDLE_EXEC-}" ]] && echo "bundle exec ${*}" >&2

RBENV_COMMAND="bundle"
RBENV_COMMAND_PATH="bundle"
set -- "bundle" "exec" "$@"

_rbe_cleanup
