# ADR 0002: MIT license and a public repository

- **Status:** Accepted
- **Date:** 2026-11-19
- **Deciders:** repo owner

## Context

The project began as a personal widget in a local repository with no
remote and no license. The owner asked on 2026-11-19 to add a license
and make the repository public.

Two things about the project matter to anyone who finds it:

- It reads the upcoming song through private macOS API, by a route that
  sidesteps a restriction Apple added (ADR-0001). It may stop working
  with any macOS or Xcode update and cannot be shipped through the App
  Store.
- It is built and signed to run locally. There is no release, no
  notarized build and no support commitment.

Publishing also exposes the commit history. All commits carried the
owner's personal email address as author.

## Decision

We will publish the repository publicly on GitHub as
`vpciii/now-playing-widget` under the MIT license, with the copyright
held under the owner's GitHub name. Before the first push, the local
commits are rewritten to use the owner's GitHub noreply address, and the
repository is configured to use it from then on.

## Alternatives considered

- **Apache 2.0** — also permissive, with an explicit patent grant. More
  text and obligations than a small personal project needs.
- **GPL 3.0** — would keep derivatives open, but discourages reuse of a
  few hundred lines of widget code for little benefit.
- **Stay private** — no exposure and no expectations. Rejected: the
  owner wants it shared.
- **Publish with the personal email in history** — simplest, but the
  address would be permanently readable and harvestable. Nothing had
  been pushed, so rewriting cost nothing.

## Consequences

- Anyone may use, modify and redistribute the code, with the notice kept
  and no warranty.
- The private API use is now public knowledge about this project. The
  README says so plainly, and says the project is not affiliated with
  Apple.
- Making a repository public is not fully reversible: clones, forks and
  caches persist after it is made private again. The license on the
  published commits cannot be withdrawn from people who already have
  them.
- The docs contain examples from the owner's own listening (song and
  station names) and mention tools on the owner's Mac. These are now
  public.
- Commit hashes changed once, at the rewrite before publishing. Hashes
  quoted in earlier conversations no longer match.
- Issues and pull requests may arrive. There is no commitment to answer
  them.

## Adoption impact

`docs/architecture.md` records the repository's location and visibility.
New commits must use the noreply address; the repository's local git
configuration sets it.

## References

- ADR-0001 — private MediaRemote for the upcoming song
- `LICENSE`
