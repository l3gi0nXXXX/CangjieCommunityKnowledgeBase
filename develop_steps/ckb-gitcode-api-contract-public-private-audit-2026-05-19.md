# CKB GitCode API Contract Public/Private Audit

Date: 2026-05-19

## Status

This document is the source-backed audit note for the public/private repository
scope in the CKB GitCode live sync documentation. Phase P0 documentation now
states the implemented contract:

- CKB GitCode live sync supports public repositories only.
- Private, internal, and unknown-visibility repositories must not enter
  knowledge acquisition, normalization, indexing, or trusted evidence.
- Operator docs must not provide repository-visibility settings that expand
  sync beyond public repositories, or any bypass instruction for non-public
  repository acquisition.

## Evidence

- `README.md` documents the public-only live sync scope and excludes private,
  internal, and unknown-visibility repositories from knowledge acquisition.
- `docs/architecture.md` constrains the source scope and request contract to
  public repositories.
- `docs/manual-acceptance-checklist.md` adds acceptance checks for public-only
  sync and absence of non-public visibility modes.
- `docs/metis-gitcodemonitor-integration.md` defines the integration contract
  as public-only and limits credential use to public repository API needs.

## Historical Analysis Boundary

Any older note that discusses possible future private repository support is
historical analysis only. It is not part of this implementation, not an
operator procedure, and not an accepted live sync mode for CKB.

Future private or internal repository support would require a separate design,
explicit security review, tests, redaction requirements, and user approval. It
must not be inferred from current credential handling or GitCode API examples.
