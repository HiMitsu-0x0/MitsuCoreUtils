# CoreUtils Documentation

This directory contains the documentation for **CoreUtils**, an independent
collection of Unix-like command-line utilities written in Zig 0.17.0.

> CoreUtils is **not** GNU Coreutils and is not affiliated with, endorsed by,
> or part of the GNU Project. See the manual's introduction for details.

## Before you contribute

AI coding assistants must read the repository-wide instructions in the root
[`AGENTS.md`](../AGENTS.md) before contributing. That file covers the Zig
version, build and licensing conventions, source-safety rules, and validation
requirements. Human contributors should read it as well.

## Files in this directory

| File | Role |
| --- | --- |
| `coreutils.texi` | The main manual, written in GNU Texinfo. This is the authoritative source for the documentation. |
| `README.md` | This guide. It explains how the documentation is organized and how to build it. |

The root-level `README.md` gives a short project overview and points here for
the full documentation. The root-level `LICENSE` file holds the complete MIT
License text; the manual's License chapter reproduces it and must stay in
agreement with that file.

## Layout

```
CoreUtils/
├── docs/
│   ├── coreutils.texi   # main manual (Texinfo source)
│   └── README.md        # this guide
├── LICENSE              # MIT License (authoritative)
├── README.md            # project overview
├── build.zig            # build configuration
└── *.zig                # one source file per utility
```

There is no `build.zig.zon` manifest and there are no third-party
documentation dependencies.

## Reading the Texinfo source

`coreutils.texi` is a plain-text file that uses GNU Texinfo markup. It is meant
to be read either as source or after being converted. A few conventions:

- `@node` and `@menu` define the navigable structure of the manual.
- `@chapter` and `@section` are the headings.
- `@code{...}`, `@option{...}`, `@command{...}`, and `@file{...}` mark up code,
  options, commands, and file names.
- `@example` blocks contain shell transcripts and command synopses.
- `@xref{...}` and `@ref{...}` create cross-references between nodes.
- A literal `@` is written as `@@`, and literal braces as `@{` and `@}`.

Every documented behavior is based on the actual source code and on running the
built programs. Known defects and behavioral differences are stated explicitly
in the "Known Issues and Behavior Differences" chapter; they are documented,
not hidden.

## Required tools

Building the documentation requires **GNU Texinfo**. The commands below were
tested with `texi2any` / `makeinfo` from GNU Texinfo 7.3.

- Info and HTML output: `makeinfo` (or `texi2any`).
- PDF output: additionally requires a TeX distribution (for example, TeX Live)
  that provides `pdflatex` and the Texinfo macros.
- `install-info` is optional and only needed if you want to register the Info
  file with a system Info directory.

Only the build tools are required; the CoreUtils utilities themselves build
with Zig alone (see the manual's "Building and Installing" chapter).

## Generating documentation

Run these commands from the project root.

### Info

```sh
makeinfo --no-split -o docs/coreutils.info docs/coreutils.texi
```

Read the result with `info -f docs/coreutils.info` or with a pager.

To install the Info file into a system Info directory (optional):

```sh
install-info --dir-file=/usr/share/info/dir docs/coreutils.info
```

### HTML

A single self-contained HTML file:

```sh
makeinfo --html --no-split -o docs/coreutils.html docs/coreutils.texi
```

Or a directory of linked HTML pages:

```sh
makeinfo --html -o docs/coreutils-html docs/coreutils.texi
```

### PDF

```sh
texi2pdf -o docs/coreutils.pdf docs/coreutils.texi
```

PDF generation fails if no TeX distribution is installed. The environment used
to prepare this documentation did not have a TeX installation, so the PDF path
was not exercised here; Info and HTML generation were both verified.

## Validating the manual

To check the Texinfo source for errors without producing a file:

```sh
makeinfo --no-split -o /dev/null docs/coreutils.texi
```

A successful run exits with status 0. Warnings, if any, are printed to
standard error and should be fixed in the source.

## Keeping the documentation accurate

- Document only behavior that the source code implements and that can be
  verified by running the utility.
- When you change a utility's options, output, or exit status, update its
  section in `coreutils.texi` in the same change.
- Keep the License chapter consistent with the root `LICENSE` file.
- Do not modify, reformat, or "fix" the `.zig` sources while editing
  documentation.
