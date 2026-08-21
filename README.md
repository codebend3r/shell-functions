# Shell Functions

> a collection of helper scripts shared amongst computers, called by name from
> your shell, and browsable through `che`

The scripts are Python. The names you type (`delete-by-ext`,
`sync-all-branches`, `show-codecs`, …) are shell functions generated from one
manifest, `bin/commands.py`, and installed into whichever shells you use.

```
che                     browse everything, arrow keys and Enter
che <command> [args…]   run one directly
delete-by-ext --path=…  or just call it by name
```

## Install

From a clone:

```sh
git clone https://github.com/codebend3r/shell-functions.git ~/Developer/git/shell-functions
~/Developer/git/shell-functions/install.sh
```

Or in one line, which clones for you:

```sh
curl -fsSL https://raw.githubusercontent.com/codebend3r/shell-functions/main/install.sh | bash
```

The first run opens a wizard: it detects your shells, shows which rc files it
would touch, offers to remove hand-written wrappers left over from before the
installer existed, and reports any external tool that is missing. Nothing is
written until it has told you what it is about to write, and every file it
edits is backed up to `~/.config/che/backups/` first.

Skip the questions with `--yes`:

```sh
./install.sh --yes                    # into the shells it detects
./install.sh --yes --shells=zsh,fish  # or the ones you name
./install.sh --dry-run                # show what would change
```

What it installs:

| Thing | Where |
| --- | --- |
| A five-line block that sources the wrappers | `~/.zshrc`, `~/.bashrc` / `~/.bash_profile`, `~/.config/fish/config.fish`, `~/.profile` |
| The wrappers themselves | `shell/che.zsh`, `shell/che.bash`, `shell/che.fish` in this repo |
| Tab completions | `shell/completions/`, wired up by the same block |
| A `che` executable, for cron and scripts that never read an rc file | `~/.local/bin/che` |
| Your answers | `~/.config/che/config.json` |

The block is delimited by `# >>> che shell functions >>>` markers and is
rewritten wholesale on every install. Everything outside the markers is yours
and is never touched. Reload with `exec zsh` (or your shell) when it finishes.

Requires **Python 3.12+** and nothing else. The installer finds a suitable
interpreter and records its path, so `/usr/bin/python3` being three years old
does not matter as long as some newer python3 exists.

## Day to day

```sh
che                  # the menu: type to filter, ↑↓ to move, Enter to run
che doctor           # is everything installed, and is every tool present?
che update           # pull the latest scripts and refresh the wrappers
che uninstall        # take the block back out
che list             # every command, one per line
```

In the menu, anything that can preview **previews by default**: pressing Enter
on `delete-by-ext` shows you what it would delete. `d` toggles that off, and
the detail pane always says which mode you are in.

Every command is also a plain shell function, so `type delete-by-ext` shows
exactly what it runs, and the destructive ones have a `-dr` twin that only
prints:

```sh
delete-by-ext --path=/Volumes/Media --ext=nfo,txt   # deletes
delete-by-ext-dr --path=/Volumes/Media --ext=nfo    # shows what it would delete
```

## Layout

```
bin/
  che.py              the dispatcher and the interactive menu
  commands.py         the command manifest: the source of truth for everything
  install.py          installer, first-run wizard, doctor, self-update
  shellgen.py         renders the wrappers and completions from the manifest
  tui.py              terminal primitives: raw input, frame buffer, prompts
  utils.py            shared library: logging, arg parsing, subprocess, files
  drives/             mount, eject, and keep-alive for the NAS volumes
  files/              delete/compress/inspect files by extension or size
  git/                branch hygiene, worktrees, GitHub Actions status
  system/             Homebrew updates, btop launcher
  video/              codec inspection, renaming, dedupe, metadata
shell/                GENERATED wrappers and completions - do not edit
test/                 pytest suites
install.sh            bootstrap for a machine with nothing on it
.zshrc                a shim that sources shell/che.zsh, kept for old setups
```

## Adding a command

1. Write the script under `bin/<category>/` and `chmod +x` it.
2. Add a `Command(...)` entry to `bin/commands.py`: name, summary, which
   script, which sound, whether it can preview, which external tools it needs,
   and the two or three questions the menu should ask.
3. `bun run generate` to rewrite `shell/`, then commit the result.
4. `che install` on each machine (or just `che update`, which does both).

There is no step where you hand-edit a wrapper into `~/.zshrc`, and no step
where you copy one machine's rc file to another.

## CLI conventions

Every script follows the same shape, described in full at the top of
`bin/utils.py`:

- **Long flags only**, `--name=value` for values.
- **Booleans** accept a bare `--flag` *and* `--flag=true|false` (plus
  `yes|no`, `1|0`, `on|off`). A bare `--flag` never swallows the next argument.
- **`--help`** on every script.
- **Destructive scripts default to dry-run.** `delete-by-ext`,
  `delete-empty-folders`, `delete-smb-files`, `files-under-size`,
  `fix-codecs`, `delete-duplicate-videos` and `rename-video-file` preview by
  default; the generated wrapper sets `DRY_RUN=false` for the real thing, and
  the `-dr` wrapper forces the preview.
- **A symlinked `--path` is refused.** `find` never followed a symlinked start
  point, so pointing a delete tool at `~/media -> /Volumes/...` used to be a
  silent no-op. Pass the real path to act on it.

## Syncing branches and worktrees

```sh
sync-all-branches       # push every worktree, collapse the pushed ones, then sync
sync-all-branches-dr    # preview only
update-from-origin      # same, but --no-push: only collapses already-pushed worktrees
```

A worktree is a temporary workspace. Once its commits are on origin the
directory holds nothing the remote doesn't, so `sync-all-branches` pushes it,
removes the directory, and leaves the branch behind as an ordinary local
branch. That also clears the `already used by worktree` pin, which is what
otherwise makes `main` un-checkoutable and stale branches un-deletable.

A worktree is only collapsed when it is **clean** *and* **fully pushed**.
Anything else is kept and reported with the reason.

## Running tests

This repo uses [Bun](https://bun.sh) as its task runner and
[uv](https://docs.astral.sh/uv/) to supply the dev tooling.

```sh
bun run test        # pytest
bun run generate    # rewrite shell/ from bin/commands.py
bun run ci          # ruff + syntax + exec bits + shebangs + generated files + pytest
```

`bun run ci` fails if `shell/` is out of date with the manifest, so a wrapper
can never drift from the command it wraps.

Neither `pytest` nor `ruff` needs to be installed globally: the scripts shell
out to `uv run --with-requirements requirements-dev.txt`, which builds an
ephemeral environment per invocation. Versions are pinned exactly in
`requirements-dev.txt`.

(Note: plain `bun test` invokes Bun's built-in JS/TS test runner, which doesn't
apply here, so always use `bun run test`.)

## External tools

The scripts shell out to these where relevant, and fail with an install hint
when one is missing. `che doctor` reports which are present and what each one
is needed for.

| Tool | Used by |
| --- | --- |
| `ffprobe` / `ffmpeg` | `show-codecs`, `fix-codecs`, `find-video-mkv-issues`, `scan-videos-audio-language` |
| `mpv` | `validate-video-files` |
| `exiftool` | `remove-metadata` |
| `gh` | `all-actions` |
| `git` | everything in `bin/git/`, and `che update` |
| `diskutil`, `osascript`, `sfltool` | `bin/drives/` (macOS only) |
| `brew` | `update-brew` |
| `btop` | `btop-launch` |

`playsound-N`, the chime each wrapper plays when it finishes, is defined
outside this repo. If it is not there the wrappers skip it silently; set
`CHE_SOUNDS=0` to turn the chimes off everywhere.

`zip`, `bc`, `jq`, `perl`, `awk` and `sort` are no longer needed: `zipfile`,
integer maths, `json`, `re` and `sorted()` cover what they were doing.

## History

These scripts were bash until August 2026. `git log` has the shell versions;
the migration commit explains each deliberate behavioural change, and anywhere
the Python intentionally differs from the bash it replaced, there is a comment
at that line saying so.

The wrappers were hand-maintained in this repo's `.zshrc` until `che` arrived,
with the documented workflow being to copy them into `~/.zshrc` by hand. That
is what `che install --replace-legacy` cleans up.
