# About This Repository

`tilde-macos` is the canonical distribution root for Tilde for macOS. It defines the complete distribution state: the Tilde source, the pinned component revisions, and every distribution tidemark.

## Repository architecture

The eight constituent component repositories live under `deps/` as Git submodules, each pointing to its writable `MeansAndMeasures` fork while preserving its GPLv3 and upstream lineage:

```text
deps/makesys     -> MeansAndMeasures/makesys
deps/transcript  -> MeansAndMeasures/transcript
deps/t3shared    -> MeansAndMeasures/t3shared
deps/t3window    -> MeansAndMeasures/t3window
deps/t3widget    -> MeansAndMeasures/t3widget
deps/t3key       -> MeansAndMeasures/t3key
deps/t3config    -> MeansAndMeasures/t3config
deps/t3highlight -> MeansAndMeasures/t3highlight
```

These are maintained components of the distribution, not disposable third-party copies. The parent repository pins their exact commits. `prime` is the working and default branch across the distribution and its component forks; a commit at the distribution root therefore identifies one coherent supported state.

GPLv3 already establishes the terms for modification and redistribution. Preserve attribution and upstream relationships, but do not add contributor-governance or maintainer-recruitment scaffolding unless the operating model actually changes.

Process documentation is intentionally lean. It exists to make decisions, validation, and consequences legible and to provide inspectable evidence of disciplined Means+Measures engineering—not to manufacture ceremony.

## Product identity and attribution

The established Tilde for macOS identity and attribution are canonical. Preserve their wording and meaning across the About dialog and command-line version output.

The About dialog title is `About Tilde for macOS`; its body is:

```text
Tilde for macOS
Version <VERSION>

A modernized macOS distribution of the Tilde text editor.
Cross-terminal compatible. M-series optimized.

© 2026 Means+Measures

Based on the groundbreaking work of G.P. Halkes, creator of Tilde and the T3 libraries.
Original work © G.P. Halkes and respective contributors.

Licensed under the GNU General Public License v3.
```

The command-line form uses `Copyright (C)` in place of the `©` glyph while preserving the same identity, attribution, and licensing statements.

## Engineering Atlas

The Engineering Atlas lives under `docs/engineering-atlas/`. Each tidemark closes an engineering epoch. For every tidemark-to-tidemark epoch, preserve one human-authored Markdown Change Record alongside the complete corpus diff that substantiates it:

```text
docs/engineering-atlas/
├── current -> tidemarks/<most-recent-tidemark>/
└── tidemarks/
    └── <tidemark>/
        └── CHANGE-RECORD.md
```

`current` must be an actual relative symlink. Advancing it exposes the most recent tidemark without copying an epoch or creating another source of truth.

Paths tell **where** engineering occurred. Tidemarks tell **when**. Tags tell the **engineering nature** of the change. Together they provide the retrieval structure; no YAML frontmatter, separate schema, or parallel metadata database is maintained.

## Change Record convention

A Change Record is a concise practical summary of the meaningful semantic changes in one epoch. Its document title identifies the preceding and current tidemarks. Each semantic change is one `## ` Level-1 entry, identified by its descriptive heading rather than a parallel numbering system, and contains these `### ` fields in order:

```markdown
# Change Record: <previous tidemark> → <current tidemark>

## <Semantic change>

### Change

### Rationale

### Impacted corpus

### Secondary downstream impacts

### Unusual impacts

### Benefits

### Time / effort cost

### Validation

### Tags

### Helpful outside resources
```

In `Impacted corpus`, name individual files when that is useful. When enumeration would obscure the change, name the lowest sensible containing directory without swallowing unrelated corpus merely for brevity.

Tags use unquoted `#tag` syntax and describe what someone may remember about the domain or nature of the work, such as `#darwin`, `#toolchain`, or `#capability-detection`. Every heading marker sequence must be followed by a mandatory ASCII space: `## Semantic change` is structural markup; `#tag` is retrieval vocabulary.

Routine maintenance churn remains only in the exhaustive corpus diff unless it becomes engineering-significant. The Change Record explains what mattered and why; it does not narrate every changed byte. Every Change Record concludes with a direct link to the complete tidemark-to-tidemark corpus diff.

## README projection

After the Atlas is established, the root `README.md` should gain a concise **What's New** section linking into `docs/engineering-atlas/current/CHANGE-RECORD.md`. It is an executive projection of the current epoch's Level-1 changes, not a duplicated changelog; the complete explanation remains in the Change Record and the exhaustive evidence remains in the corpus diff.
