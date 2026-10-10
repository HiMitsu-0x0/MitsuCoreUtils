# AGENTS.md

Instructions for AI coding assistants and contributors working in this
repository. Read this file before making changes.

## Project

CoreUtils is an independent collection of Unix-like command-line utilities
written in **Zig 0.17.0**. It is **not** GNU Coreutils and is not affiliated
with, endorsed by, or part of the GNU Project.

## Repository conventions

- **Zig version:** 0.17.0 — the version the project is built and verified with.
- **One source file per utility:** each utility lives in a single top-level
  `<name>.zig` file that defines a `main` function.
- **Register new utilities:** add the name to the `utils` array in
  `build.zig`. The build compiles `<name>.zig` and installs the executable.
  Do not rename or remove a utility without updating `build.zig` and the
  documentation.
- **No external dependencies:** use only the Zig standard library and libc
  (`link_libc = true` is set in `build.zig`). There is no `build.zig.zon`.

## Licensing

- The project is licensed under the **MIT License**; the authoritative text is
  the root `LICENSE` file.
- New or modified Zig source files must begin with these two lines:

  ```zig
  // Copyright (c) 2026 HiMitsu <himitsutha@protonmail.com>
  // SPDX-License-Identifier: MIT
  ```

- Most files already carry this header. The following files do not yet have it;
  adding it is a welcome, non-behavioral change: `base64.zig`, `date.zig`,
  `env.zig`, `stat.zig`, `test.zig`.
- Do not change the license or add code under different terms. The project
  bundles no third-party code.

## Documentation

- The main manual is `docs/coreutils.texi` (GNU Texinfo). It must stay
  synchronized with the actual implementation: document only verified
  behavior, and describe known limitations and differences honestly.
- **Before editing documentation, read `docs/README.md` and follow its
  guidelines.**
- Keep the manual's License chapter consistent with the root `LICENSE` file.
- Do not change a utility's options, output, or exit status without updating
  its section in `docs/coreutils.texi`.

## Source safety

- **During documentation-only tasks, do not modify source files or build
  configuration** — no edits to `.zig` files, `build.zig`, or other build
  files.
- Do not reformat, refactor, or run formatters against source files unless the
  task explicitly asks for it.
- If instructions are ambiguous or a change could be destructive, stop and ask
  instead of guessing.

## Validation

- Build: `zig build` (installs executables into `zig-out/bin/`).
- Validate the manual with GNU Texinfo:
  `makeinfo --no-split -o /dev/null docs/coreutils.texi`.
- There is no automated test suite and `build.zig` defines no `test` step. Run
  the checks that apply and **report any checks that could not be completed**
  (for example, PDF generation requires a TeX installation).
