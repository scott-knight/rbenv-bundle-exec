# rbenv-bundle-exec
# Automatically runs ruby gem executables through `bundle exec` inside projects.

[[ -n "$NO_BUNDLE_EXEC" ]] && return
[[ "$RBENV_COMMAND" == "bundle" || "$RBENV_COMMAND" == "gem" ]] && return

command -v bundle > /dev/null 2>&1 || return

if [[ -f "$HOME/.no_bundle_exec" ]]; then
  while IFS= read -r skip_cmd || [[ -n "$skip_cmd" ]]; do
    [[ -z "$skip_cmd" || "$skip_cmd" == \#* ]] && continue
    [[ "$RBENV_COMMAND" == "$skip_cmd" ]] && return
  done < "$HOME/.no_bundle_exec"
fi

if [[ -z "$BUNDLE_GEMFILE" ]]; then
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/rbenv-bundle-exec"
  cache_key="${PWD//\//%2F}"
  cache_file="$cache_dir/$cache_key"

  if [[ -f "$PWD/Gemfile" ]]; then
    BUNDLE_GEMFILE="$PWD/Gemfile"
  elif [[ -f "$cache_file" ]]; then
    IFS= read -r cached_gemfile < "$cache_file"

    if [[ "$cached_gemfile" == "__none__" ]]; then
      return
    elif [[ -f "$cached_gemfile" ]]; then
      BUNDLE_GEMFILE="$cached_gemfile"
    fi
  fi

  if [[ -z "$BUNDLE_GEMFILE" ]]; then
    dir="$PWD"
    depth=0

    while [[ -n "$dir" && $depth -lt 10 ]]; do
      if [[ -f "$dir/Gemfile" ]]; then
        BUNDLE_GEMFILE="$dir/Gemfile"
        break
      fi

      [[ "$dir" == "/" ]] && break
      dir="${dir%/*}"
      (( depth++ ))
    done

    mkdir -p "$cache_dir" 2> /dev/null

    if [[ -n "$BUNDLE_GEMFILE" ]]; then
      printf '%s\n' "$BUNDLE_GEMFILE" > "$cache_file"
    else
      printf '%s\n' "__none__" > "$cache_file"
      return
    fi
  fi

  export BUNDLE_GEMFILE
fi

[[ -n "$DEBUG_RBENV_BUNDLE_EXEC" ]] && echo "bundle exec ${*}" >&2

RBENV_COMMAND="bundle"
RBENV_COMMAND_PATH="bundle"
set -- "bundle" "exec" "${@}"
