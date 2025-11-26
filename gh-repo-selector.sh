#!/usr/bin/env bash

set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "The '$1' command is required for this script." >&2
    exit 1
  fi
}

install_gum() {
  echo "Gum is required but was not found. Attempting to install..." >&2

  if command -v brew >/dev/null 2>&1; then
    if brew install gum >/dev/null 2>&1; then
      return 0
    fi
  fi

  if command -v apt-get >/dev/null 2>&1; then
    if sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y gum >/dev/null 2>&1; then
      return 0
    fi
  fi

  if command -v yum >/dev/null 2>&1; then
    if sudo yum install -y gum >/dev/null 2>&1; then
      return 0
    fi
  fi

  if command -v pacman >/dev/null 2>&1; then
    if sudo pacman -Sy --noconfirm gum >/dev/null 2>&1; then
      return 0
    fi
  fi

  if command -v zypper >/dev/null 2>&1; then
    if sudo zypper --non-interactive install gum >/dev/null 2>&1; then
      return 0
    fi
  fi

  if command -v go >/dev/null 2>&1; then
    if go install github.com/charmbracelet/gum@latest >/dev/null 2>&1; then
      return 0
    fi
  fi

  echo "Automatic installation failed. Please install gum manually from https://github.com/charmbracelet/gum." >&2
  return 1
}

if ! command -v gum >/dev/null 2>&1; then
  install_gum
fi

require_command gum
require_command gh
require_command git

gum style --foreground 213 --bold "GitHub Repository Selector"
gum style --foreground 244 "Retrieve a user's repositories via the GitHub CLI, then choose one with Gum."

read_username() {
  local name
  name="$(gum input --placeholder "octocat" --prompt "GitHub username: ")"
  # Trim whitespace
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  printf '%s' "$name"
}

username="$(read_username)"
if [[ -z "$username" ]]; then
  gum style --foreground 214 "No username provided. Exiting."
  exit 0
fi

gum style --foreground 244 "Fetching repositories for $username ..."

if ! repo_lines="$(
  gh repo list "$username" \
    --limit 200 \
    --json nameWithOwner,description \
    --jq '.[] | "\(.nameWithOwner)\t\((.description // "No description provided.") | gsub("\n"; " "))"'
)"; then
  gum style --foreground 9 "Failed to fetch repositories for $username (does the user exist?)."
  exit 1
fi

repo_lines="$(printf '%s\n' "$repo_lines" | sed '/^[[:space:]]*$/d')"
if [[ -z "$repo_lines" ]]; then
  gum style --foreground 214 "No repositories found for $username."
  exit 0
fi

selected="$(
  printf '%s\n' "$repo_lines" |
    gum choose --height 15 --header "Select a repository to inspect"
)"

if [[ -z "$selected" ]]; then
  gum style --foreground 214 "Selection cancelled."
  exit 0
fi

selected_repo="${selected%%$'\t'*}"
selected_desc="${selected#*$'\t'}"

gum style --foreground 49 --bold "Repository:"
gum style --foreground 49 "$selected_repo"
gum style --foreground 244 "Description: $selected_desc"

# Attempt to open in browser, fall back to CLI output if needed
open_repo_in_browser() {
  if gh repo view "$selected_repo" --web >/dev/null 2>&1; then
    gum style --foreground 49 "Opened $selected_repo in your browser."
  else
    gum style --foreground 214 "Unable to open a browser window here. Showing repository details in the terminal instead."
    gh repo view "$selected_repo"
  fi
}

show_repo_details() {
  gh repo view "$selected_repo"
}

clone_repo_prompt() {
  gum style --foreground 244 "Leave blank to clone into the default '$selected_repo' directory."
  local target_dir
  target_dir="$(gum input --placeholder "$selected_repo" --prompt "Clone destination: ")"

  attempt_clone_with_fallback "$target_dir"
}

attempt_clone_with_fallback() {
  local destination="$1"
  local repo_url="https://github.com/$selected_repo.git"
  local gh_args=("$selected_repo")
  local git_args=("$repo_url")

  if [[ -n "$destination" ]]; then
    gh_args+=("$destination")
    git_args+=("$destination")
  fi

  if gh repo clone "${gh_args[@]}"; then
    if [[ -n "$destination" ]]; then
      gum style --foreground 49 "Repository cloned into $destination"
    else
      gum style --foreground 49 "Repository cloned into ./$(basename "$selected_repo")"
    fi
    return 0
  fi

  gum style --foreground 214 "SSH-based clone failed (is your GitHub SSH key set up?). Trying HTTPS instead..."

  if git clone "${git_args[@]}"; then
    if [[ -n "$destination" ]]; then
      gum style --foreground 49 "Repository cloned into $destination via HTTPS"
    else
      gum style --foreground 49 "Repository cloned into ./$(basename "$selected_repo") via HTTPS"
    fi
  else
    if [[ -n "$destination" ]]; then
      gum style --foreground 9 "Failed to clone $selected_repo into $destination, even via HTTPS."
    else
      gum style --foreground 9 "Failed to clone $selected_repo, even via HTTPS."
    fi
  fi
}

while true; do
  action="$(
    gum choose --header "Select an action for $selected_repo" \
      "Open in browser" \
      "Show repo details here" \
      "Clone repository" \
      "Quit"
  )"

  case "$action" in
  "Open in browser") open_repo_in_browser ;;
  "Show repo details here") show_repo_details ;;
  "Clone repository") clone_repo_prompt ;;
  "Quit" | "")
    gum style --foreground 244 "Done."
    exit 0
    ;;
  esac
done
