# GitHub Repo Selector

Interactive TUI helper built with [gum](https://github.com/charmbracelet/gum) and the GitHub CLI for browsing a user's repositories, drilling into their details, and cloning them locally. It is designed to feel at home inside a terminal-first workflow.

## Requirements

- `gum` for inputs and menus
- `gh` authenticated with the GitHub account you want to use for API calls
- `git` for fallback cloning over HTTPS
- Bash 4+ and a POSIX-like environment (macOS, Linux, WSL, etc.)

Make sure `gh auth status` succeeds before running the script.

## Usage

```bash
./gh-repo-selector.sh
```

1. Enter a GitHub username when prompted.
2. Use the Gum-powered list to pick a repository. (Descriptions are shown inline.)
3. Choose what to do with the repo:
   - Open it in your browser via `gh repo view --web`.
   - Show details in the terminal (`gh repo view`).
   - Clone it. You can accept the default directory name or provide a destination. The script first attempts `gh repo clone` (SSH) and falls back to `git clone` over HTTPS if necessary.
4. Repeat actions or quit from the final menu.

If the user has no repositories, or you cancel any prompt, the script exits gracefully.

## Notes

- Network/API failures are surfaced with friendly Gum-styled messages.
- The script enforces dependency checks up front and trims whitespace from user input to avoid subtle errors.
- Customize theme/colors by modifying the `gum style` calls near the top of the script.
