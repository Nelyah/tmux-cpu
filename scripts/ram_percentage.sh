#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

ram_percentage_format="%3.1f%%"
pagesize="$(pagesize)"

sum_macos_vm_stats() {
  grep -Eo '[0-9]+' |
    awk '{ a += $1 * '"$pagesize"' } END { print a }'
}

print_ram_percentage() {
  ram_percentage_format=$(get_tmux_option "@ram_percentage_format" "$ram_percentage_format")

  if command_exists "free"; then
    cached_eval free | awk -v format="$ram_percentage_format" '$1 ~ /Mem/ {printf(format, 100*$3/$2)}'
  elif command_exists "vm_stat"; then
    # page size of 4096 bytes
    stats="$(cached_eval vm_stat)"
    free_fields='Pages free'
    active_use_fields='Pages active|Pages wired down'
    cached_fields='Pages purgeable|File-backed pages|Pages occupied by compressor|Pages speculative'

    used_and_cached=$(
      echo "$stats" |
        grep -E "(${active_use_fields}|${cached_fields})" |
        sum_macos_vm_stats
    )

    cached=$(
      echo "$stats" |
        grep -E "(${cached_fields})" |
        sum_macos_vm_stats
    )

    free=$(
      echo "$stats" |
        grep -E "(${free_fields})" |
        sum_macos_vm_stats
    )

    used=$((used_and_cached - cached))
    total=$((used_and_cached + free))

    echo "$used $total" | awk -v format="$ram_percentage_format" '{printf(format, 100*$1/$2)}'
  fi
}

main() {
  print_ram_percentage
}
main
