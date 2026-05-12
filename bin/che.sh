#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/utils.sh" --source-only

set -euo pipefail

# v0.3.0

VERSION="0.3.0"

# Files in bin/ that are not user-facing subcommands
EXCLUDED=(che.sh utils.sh pre-push.sh version-bump.sh)

# Menu items shown by the interactive picker.
# Format: script_name|description|prompts
# Prompts is a comma-separated list of: path, size, dry-run
MENU_ITEMS=(
  "files-under-size|List files under a size threshold|path,size,dry-run"
  "delete-empty-folders|Remove empty directories recursively|path,dry-run"
)

is_excluded() {
  local name=$1
  local x
  for x in "${EXCLUDED[@]}"; do
    [[ "$name" == "$x" ]] && return 0
  done
  return 1
}

list_command_names() {
  find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -perm -u+x \
    | sort \
    | while IFS= read -r f; do
        name=$(basename "$f")
        is_excluded "$name" && continue
        printf '%s\n' "${name%.sh}"
      done
}

list_commands() {
  list_command_names | sed 's/^/  /'
}

usage() {
  cat <<EOF
Usage: che <command> [args...]
       che              (interactive menu)

Run \`che <command> --help\` for details on a specific command.

Commands:
$(list_commands)

Options:
  -h, --help     Show this help
  -v, --version  Show version
EOF
}

#
# Interactive menu
#

tui_enter() { printf '\e[?1049h\e[?25l' > /dev/tty; }
tui_leave() { printf '\e[?25h\e[?1049l' > /dev/tty; }

COLLECTED_ARGS=()

collect_args() {
  local prompts=$1
  local IFS=','
  local p input
  COLLECTED_ARGS=()

  for p in $prompts; do
    case "$p" in
      path)
        printf 'Path: '
        IFS= read -r input
        if [[ -z "$input" ]]; then
          warning "Path is required."
          return 1
        fi
        COLLECTED_ARGS+=("--path=$input")
        ;;
      size)
        printf 'Size threshold (e.g. 1MB, 500K): '
        IFS= read -r input
        if [[ -z "$input" ]]; then
          warning "Size is required."
          return 1
        fi
        COLLECTED_ARGS+=("--size=$input")
        ;;
      dry-run)
        printf 'Dry run? [Y/n]: '
        IFS= read -r input
        if [[ -z "$input" || "$input" =~ ^[Yy] ]]; then
          COLLECTED_ARGS+=("--dry-run")
        fi
        ;;
    esac
  done
}

run_command() {
  local cmd=$1
  local prompts=$2
  local script="${SCRIPT_DIR}/${cmd}.sh"

  tui_leave

  printf '\n'
  info "Running: $cmd"
  printf '\n'

  if [[ -n "$prompts" ]]; then
    if ! collect_args "$prompts"; then
      printf '\n'
      note "Cancelled. Press any key to return to the menu..."
      IFS= read -rsn1 _ < /dev/tty || true
      tui_enter
      return
    fi
    printf '\n'
    info "Args: ${COLLECTED_ARGS[*]:-<none>}"
    printf '\n'
    bash "$script" "${COLLECTED_ARGS[@]}" || true
  else
    bash "$script" || true
  fi

  printf '\n'
  note "Press any key to return to the menu..."
  IFS= read -rsn1 _ < /dev/tty || true

  tui_enter
}

draw_menu() {
  local selected=$1
  local i item cmd desc

  printf '\e[H\e[2J' > /dev/tty

  {
    printf '\n'
    printf '   \e[35m╔═╗┬ ┬┌─┐\e[0m\n'
    printf '   \e[35m║  ├─┤├┤ \e[0m\n'
    printf '   \e[35m╚═╝┴ ┴└─┘\e[0m  \e[32mShell helpers dispatcher\e[0m\n'
    printf '\n'

    for i in "${!MENU_ITEMS[@]}"; do
      item="${MENU_ITEMS[i]}"
      cmd="${item%%|*}"
      desc="${item#*|}"
      desc="${desc%%|*}"

      if (( i == selected )); then
        printf '  \e[36m▶ %d. %s — %s\e[0m\n' "$((i + 1))" "$cmd" "$desc"
      else
        printf '    %d. %s — %s\n' "$((i + 1))" "$cmd" "$desc"
      fi
    done

    printf '\n  \e[90m↑↓\e[0m Navigate  |  \e[90mEnter\e[0m Select  |  \e[90mQ\e[0m Quit\n'
  } > /dev/tty
}

read_key() {
  local key c1 c2

  if ! IFS= read -rsn1 key < /dev/tty; then
    return 1
  fi

  if [[ $key == $'\e' ]]; then
    IFS= read -rsn1 -t 0.1 c1 < /dev/tty 2>/dev/null || c1=''
    IFS= read -rsn1 -t 0.1 c2 < /dev/tty 2>/dev/null || c2=''
    key+="${c1}${c2}"
  fi

  printf '%s' "$key"
}

item_field() {
  local item=$1 idx=$2
  local IFS='|'
  local -a parts=()
  read -r -a parts <<< "$item"
  printf '%s' "${parts[$idx]:-}"
}

run_menu() {
  if ! { : >/dev/tty; } 2>/dev/null; then
    warning "Interactive menu requires a terminal"
    return 1
  fi

  local total=${#MENU_ITEMS[@]}
  local selected=0
  local key idx chosen cmd prompts

  trap 'tui_leave' EXIT INT TERM

  tui_enter

  while true; do
    draw_menu "$selected"

    key=$(read_key) || break

    case "$key" in
      $'\e[A'|k)
        (( selected = (selected - 1 + total) % total ))
        ;;
      $'\e[B'|j)
        (( selected = (selected + 1) % total ))
        ;;
      '')
        chosen="${MENU_ITEMS[selected]}"
        cmd=$(item_field "$chosen" 0)
        prompts=$(item_field "$chosen" 2)
        run_command "$cmd" "$prompts"
        ;;
      q|Q|$'\e')
        break
        ;;
      [1-9])
        idx=$((key - 1))
        if (( idx < total )); then
          selected=$idx
          chosen="${MENU_ITEMS[idx]}"
          cmd=$(item_field "$chosen" 0)
          prompts=$(item_field "$chosen" 2)
          run_command "$cmd" "$prompts"
        fi
        ;;
    esac
  done

  tui_leave
  return 0
}

#
# Argument routing
#

case "${1:-}" in
  -h|--help)    usage; exit 0 ;;
  -v|--version) echo "che v$VERSION"; exit 0 ;;
  ''|--menu)    run_menu; exit $? ;;
esac

cmd=$1
shift

# Reject names that could escape bin/ or reference hidden files
if [[ "$cmd" == */* || "$cmd" == .* ]]; then
  warning "Invalid command name: $cmd"
  exit 1
fi

script="${SCRIPT_DIR}/${cmd}.sh"
name=$(basename "$script")

if is_excluded "$name" || [[ ! -x "$script" ]]; then
  warning "Unknown command: $cmd"
  echo
  usage
  exit 1
fi

exec bash "$script" "$@"
