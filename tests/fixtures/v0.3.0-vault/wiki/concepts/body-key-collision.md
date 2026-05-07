---
type: concept
title: Body Key Collision Test
created: 2026-01-15
confidence: medium
---

# Body Key Collision

This page intentionally has a line in the body that looks like a YAML field.
The migration must NOT mistake it for an existing frontmatter key.

tier: this is body text, not a YAML field
cluster: also body text

The `tier:` and `cluster:` lines above must NOT prevent inject_field_if_missing
from adding those fields to the frontmatter.
