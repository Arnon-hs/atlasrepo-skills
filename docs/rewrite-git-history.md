# Rewrite Git History Authors

This repository has commits with more than one author or committer identity. GitHub contributor attribution is based on Git commit metadata, so changing the visible repository contributor list requires changing the commits themselves.

## Author and committer

Git stores two identities on every commit:

- Author: the person who originally wrote the change.
- Committer: the person or system that created the commit object in this repository.

For example, a commit created through a GitHub pull request can keep the original author but use `GitHub <noreply@github.com>` as the committer.

## Git config only affects future commits

Changing local settings such as `user.name` and `user.email` affects only new commits created after that change. Existing commits keep the metadata already stored in their commit objects.

To change old commits, the repository history must be rewritten. This is destructive because every changed commit receives a new hash, and all branches, tags, pull requests, forks, and collaborators that reference the old hashes can be affected.

## Current target identity

Use one identity for both author and committer:

```text
Arnon-hs <49660318+Arnon-hs@users.noreply.github.com>
```

This noreply email matches the current GitHub user id for `Arnon-hs` and is present in the repository history. If this ever cannot be verified, use `YOUR_GITHUB_NOREPLY_EMAIL` as a placeholder until the correct GitHub noreply email is confirmed.

## Create a mirror backup first

Before rewriting anything, create a separate mirror backup outside the working checkout:

```bash
git clone --mirror git@github.com:Arnon-hs/atlasrepo-skills.git atlasrepo-skills.backup.git
```

Keep this backup until the rewritten repository has been verified and all collaborators have moved to the new history.

## Run the rewrite script safely

Install `git-filter-repo` if needed:

```bash
python3 -m pip install --user git-filter-repo
```

Run from a clean working tree:

```bash
git status --short
```

Then run the script with an explicit target email and confirmation flag:

```bash
TARGET_AUTHOR_EMAIL="49660318+Arnon-hs@users.noreply.github.com" CONFIRM_REWRITE_HISTORY=1 bash scripts/rewrite-git-authors.sh
```

The script refuses to run when:

- it is not inside a Git repository;
- `git-filter-repo` is missing;
- the working tree is dirty;
- `CONFIRM_REWRITE_HISTORY=1` is missing;
- `TARGET_AUTHOR_EMAIL` is missing.

## Verify the rewrite

After the script completes, verify author and committer metadata:

```bash
git log --format="%h | author=%an <%ae> | committer=%cn <%ce>" --all | head -50
git log --format="%an <%ae>" --all | sort -u
git log --format="%cn <%ce>" --all | sort -u
git shortlog -sne --all
```

Only this identity should remain:

```text
Arnon-hs <49660318+Arnon-hs@users.noreply.github.com>
```

## Force-push only after verification

Do not force-push until the backup exists and local verification shows only the target identity.

`git-filter-repo` can remove the `origin` remote as a safety measure. If that happens, re-add it before pushing:

```bash
git remote add origin git@github.com:Arnon-hs/atlasrepo-skills.git
```

When ready, push the rewritten mirror/history:

```bash
git push --force --mirror origin
```

Warning: this updates remote refs to the rewritten history. Confirm that no branch or tag should keep old hashes before running it.

## Collaborator recovery after force push

After the force push, collaborators must stop using the old local history. The simplest recovery path is usually:

```bash
git fetch --all --prune
git switch main
git reset --hard origin/main
```

Any local feature branches created from the old history need to be rebased, cherry-picked, or recreated on top of the rewritten branch.

## Safer alternative

If rewriting shared history is too risky, create a new clean repository instead. Copy the current code into it and make one initial commit using:

```text
Arnon-hs <49660318+Arnon-hs@users.noreply.github.com>
```

This avoids changing existing commit hashes in the current repository, but it also loses the old detailed commit history in the new repository.
