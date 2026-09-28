# Issue tracker: GitHub

Issues for this repo live on GitHub at `Hash-Studios/Prism`. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, and fetch labels with `--json labels`.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply or remove labels**: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Comments and closes reach real users. Do them only when the user asked.

`gh` infers the repo from `git remote -v` inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** (Set to `yes` if external PRs count as feature requests; `/triage` reads this flag.)

When set to `yes`, PRs use the same labels and states as issues, through the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>`.
- **List external PRs**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`, then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE`.
- **Comment, label, close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

Issues and PRs share one number space. Resolve a bare number with `gh pr view <n>` and fall back to `gh issue view <n>`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.
