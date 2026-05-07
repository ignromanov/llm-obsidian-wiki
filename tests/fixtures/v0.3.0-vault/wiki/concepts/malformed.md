---
type: concept
title: Malformed YAML Test
created: 2026-01-15

# Malformed page — missing closing ---

This page has an opening `---` but no closing `---`.
The migration must SKIP this page and report it as malformed,
not silently process it or corrupt it.
