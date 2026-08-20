#!/usr/bin/env python3
"""🔖 Cut a patch version, regenerate the changelog, and re-tag.

VESTIGIAL. This targets a pnpm monorepo with `pnpm changelog` and
`pnpm version:patch` scripts, neither of which exists in this repo. It is kept
only so the migration is complete; do not run it here.

Usage:
  version-bump.py [--dry-run]

Options:
  --dry-run   Print each command instead of running it
  --help      Show help
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from utils import (
    add_bool_flag,
    build_parser,
    log,
    require_binary,
    run,
    run_cli,
    run_output,
    warning,
)

__version__ = "1.0.0"


def main(argv: list[str] | None = None) -> int:
    parser = build_parser(
        prog="version-bump",
        description="🔖 Cut a patch version, regenerate the changelog, and re-tag.",
    )
    add_bool_flag(parser, "--dry-run", help="Print each command instead of running it")
    args = parser.parse_args(argv)

    warning("⚠️  version-bump targets a pnpm monorepo and does not apply to this repo.")

    require_binary("npm")
    require_binary("pnpm")
    require_binary("git")

    def step(message: str, argv_step: list[str]) -> None:
        log(message)
        if args.dry_run:
            log(f"  🪄 Would run: {' '.join(argv_step)}")
            return
        run(argv_step)

    step("creating patch version", ["npm", "version", "patch"])
    step("generating changelog", ["pnpm", "changelog"])

    current_tag = run_output(["git", "describe"])
    log(f"current tag: {current_tag}")

    step("removing the tag so the squashed commit can carry it", ["git", "tag", "-d", current_tag])
    step(
        f"updating all apps and libraries with tag version {current_tag}",
        ["pnpm", "version:patch"],
    )

    step("squashing commits", ["git", "add", "-A"])
    step("committing", ["git", "commit", "-n", "--no-edit"])
    step("re-applying the tag", ["git", "tag", current_tag])
    return 0


if __name__ == "__main__":
    run_cli(main)
