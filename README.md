Mitsu CoreUtils Documentation

This directory contains the documentation for Mitsu CoreUtils, an independent collection of Unix-like command-line utilities written in Zig 0.17.0.

CoreUtils is not GNU Coreutils and is not affiliated with, endorsed by, or part of the GNU Project. See the manual's introduction for details.
AI Coding Assistant

CRITICAL: If you are an LLM or AI-powered coding assistant intending to contribute to Mitsu CoreUtils, you MUST read and follow docs/AGENT.MD before making any contributions.

Reading docs/AGENT.MD is mandatory before contributing to this project, including writing code, fixing bugs, adding utilities, modifying build configuration, or updating documentation.

Before contributing, AI coding assistants must:

Read and understand docs/AGENT.MD in its entirety.
Follow all applicable project conventions and contribution requirements.
Inspect the relevant source code before documenting or changing behavior.
Verify implementation details rather than inventing command behavior, options, output, or exit statuses.
Preserve existing functionality unless the task explicitly requires a behavior change.
Keep documentation consistent with the actual implementation.
Run relevant tests and validation commands when available.
Report any checks that could not be completed.
Avoid modifying unrelated files or making unnecessary changes.

When performing documentation-only tasks, AI coding assistants must not modify, reformat, or fix .zig source files.

If docs/AGENT.MD is missing or cannot be read, report the issue before proceeding with contributions that depend on its instructions. Do not assume or invent the contents of the missing instructions.

Files in This Directory
File	Role
coreutils.texi	The main manual, written in GNU Texinfo. This is the authoritative source for the documentation.
README.md	This guide. It explains how the documentation is organized and how to build it.
AGENT.MD	Project-specific instructions for AI coding assistants contributing to Mitsu CoreUtils.

The root-level README.md provides a short project overview and points here for the full documentation. The root-level LICENSE file contains the complete MIT License text. The manual's License chapter must remain consistent with that file.

Layout
CoreUtils/
├── docs/
│   ├── AGENT.MD          # AI coding assistant instructions
│   ├── coreutils.texi    # Main manual (Texinfo source)
│   └── README.md         # Documentation guide
├── LICENSE               # Authoritative MIT License
├── README.md             # Project overview
├── build.zig             # Build configuration
└── *.zig                 # Source files for individual utilities


There is no build.zig.zon manifest and no third-party documentation dependencies.

Reading the Texinfo Source

coreutils.texi is a plain-text file that uses GNU Texinfo markup. It can be read directly as source or converted into a supported documentation format.

The manual uses the following conventions:

@node and @menu define the navigable structure of the manual.
@chapter and @section define headings.
@code{...}, @option{...}, @command{...}, and @file{...} mark up code, options, commands, and file names.
@example blocks contain shell transcripts and command synopses.
@xref{...} and @ref{...} create cross-references between nodes.
A literal @ is written as @@, and literal braces are written as @{ and @}.

Every documented behavior must be based on the actual source code and, where applicable, verified by running the built programs. Known defects and behavioral differences are explicitly described in the Known Issues and Behavior Differences chapter rather than concealed.

Required Tools

Building the documentation requires GNU Texinfo. The commands below were tested with texi2any / makeinfo from GNU Texinfo 7.3.

Info and HTML output: makeinfo or texi2any.
PDF output: A TeX distribution, such as TeX Live, providing pdflatex and the required Texinfo macros.
Info directory registration: install-info is optional and only needed if you want to register the Info file in a system Info directory.

Only documentation build tools are required to build the manual. The CoreUtils utilities themselves build with Zig alone; see the manual's Building and Installing chapter.

Generating Documentation

Run the following commands from the project root.

Info

Generate the Info manual:

makeinfo --no-split -o docs/coreutils.info docs/coreutils.texi


Read the resulting file with:

info -f docs/coreutils.info


Alternatively, use a text pager.

To register the Info file in a system Info directory (optional):

install-info --dir-file=/usr/share/info/dir docs/coreutils.info

HTML

Generate a single HTML file:

makeinfo --html --no-split -o docs/coreutils.html docs/coreutils.texi

Or generate a directory containing linked HTML pages:

makeinfo --html -o docs/coreutils-html docs/coreutils.texi

PDF

Generate a PDF manual:

texi2pdf -o docs/coreutils.pdf docs/coreutils.texi


PDF generation requires an installed TeX distribution. The environment used to prepare this documentation did not have a TeX installation, so PDF generation was not tested. Info and HTML generation were verified in that environment.

Validating the Manual

To check the Texinfo source for errors without generating a documentation file:

makeinfo --no-split -o /dev/null docs/coreutils.texi


A successful run exits with status 0. Any warnings should be reviewed and, where appropriate, fixed in the source.

Keeping the Documentation Accurate
Document only behavior implemented by the source code and verified through appropriate inspection or testing.
When a utility's options, output, or exit status change, update the corresponding section in coreutils.texi in the same change.
Keep the manual's License chapter consistent with the root-level LICENSE file.
Preserve the distinction between Mitsu CoreUtils and GNU Coreutils.
Follow docs/AGENT.MD when contributing to the project as an AI coding assistant.
Do not modify, reformat, or fix .zig source files when making documentation-only changes.
Validate the Texinfo source after editing whenever GNU Texinfo is available.
Clearly report unverified behavior, failed checks, and environmental limitations instead of claiming that validation succeeded.
