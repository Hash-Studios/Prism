# Triage labels

The skills use five canonical triage roles. This table maps each role to the label string in this repo.

| Canonical role    | Label in our tracker | Meaning                                  |
| ----------------- | -------------------- | ---------------------------------------- |
| `needs-triage`    | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`      | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent` | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human` | `ready-for-human`    | Requires human implementation            |
| `wontfix`         | `wontfix`            | Will not be actioned                     |

When a skill names a role (for example "apply the AFK-ready triage label"), use the label string from this table.

Of these, only `wontfix` exists on `Hash-Studios/Prism` today. Create the others the first time `/triage` applies them (`gh label create <name>`). The repo also has older labels (`bug`, `enhancement/new feature`, `feature_request`, `UI/UX`, `question`, `duplicate`, `invalid`); read them as type hints, not triage states.

Edit the right-hand column to match the labels you use.
