# work-git-contributions

Reflects the **cadence** of my private work commits onto my public GitHub
contribution graph — without exposing any code, commit messages, or diffs.

`mirror.sh` reads only the author *dates* of my commits from configured work
repos and replays each one here as an empty commit. Push this repo to GitHub
and the graph fills in to match the real shape of the work.

## Setup

1. Point it at your work repos and set your identities:

   ```bash
   cp repos.conf.example repos.conf   # already done if repos.conf exists
   $EDITOR repos.conf
   ```

   - `SOURCES` — absolute paths to the work repos to read from.
   - `AUTHORS` — how *you* are identified in those repos (e.g. `matt@pickleai.com`).
     Only commits by these authors are mirrored.
   - `MIRROR_EMAIL` — identity stamped on the generated commits. **Must be an
     email verified on your GitHub account** or the commits won't count (see below).

   `repos.conf` is gitignored, so your private repo paths are never pushed.

2. Preview, then import:

   ```bash
   ./mirror.sh --dry-run   # list what would be imported
   ./mirror.sh             # create the empty mirror commits
   ```

   Re-run any time — it only imports commits that are new since last run
   (each mirror commit records its source hash in a `Source-Commit:` trailer).

3. Push:

   ```bash
   git remote add origin git@github.com:<you>/work-git-contributions.git
   git push -u origin main
   ```

## Why the mirror email matters

GitHub only counts a commit toward your contribution graph when the commit's
**author email is verified on your account** and the commit is on the repo's
default branch. Your work commits are authored with your *work* email, which
GitHub won't attribute to you publicly — so the mirror commits are re-stamped
with `MIRROR_EMAIL` (your personal/verified email) while preserving the
original dates.

## Notes

- Only commit dates cross over. No file contents, messages, or diffs are read.
- Merge commits are skipped (`--no-merges`) to avoid inflating counts.
- GitHub's graph displays roughly the trailing 12 months; set `SINCE` in
  `repos.conf` to skip importing older history.
- Mirror commit messages are the generic `Work contribution` — the only work
  metadata retained is the opaque source hash in the trailer, used for dedup.
