# jenkins-local

A real Jenkins on your own machine for trying any project's `Jenkinsfile` before you push. It
builds on demand from your working tree; it is not a CI server.

```bash
./install.sh                 # once per machine: links bin/jenkins-local into ~/.local/bin
jenkins-local selftest       # check this machine: builds a sample project, ok/FAIL per feature
cd ~/path/to/some-repo       # any git repo with a Jenkinsfile
jenkins-local                # build it, stream the log, exit with the build's result
```

Jenkins runs in Docker at http://127.0.0.1:8090 (localhost only, no login), with the Docker
Pipeline plugin, so `agent { docker { image '...' } }` works.

## What a build does

1. Starts Jenkins if it isn't running.
2. Snapshots the working tree as a commit (what git would commit: tracked + untracked,
   minus `.gitignore`d files such as `.venv` and `.env`) and pushes it to a local snapshot
   repo, on a branch named like yours. A throwaway index is used: your index, branch and
   files are untouched. No commit needed in your repo.
3. Creates or updates a Multibranch project named after the repo, reading that snapshot
   repo, so the build is a real checkout: `checkout scm`, `BRANCH_NAME` and `GIT_COMMIT`
   work as on a CI server. Each branch gets its own job (`<repo> » <branch>`).
4. Gives this machine every agent label the Jenkinsfile asks for (`agent { label 'gpu' }`,
   `docker { label ... }`, `node('linux && x64')`): it is the only agent, and otherwise such
   a stage would wait forever. Labels are only added, and `status` lists them.
5. Runs that branch's job, streams the log, deletes the workspace, and exits 0 on success.

## Secrets

`withCredentials([string(credentialsId: 'ID', variable: ...)])` finds secrets in two places:

- **The repo's `.env`** (default): each `KEY=value` line becomes a secret for that repo only,
  overriding a global one with the same ID. `-e FILE` uses another file; `--no-env` none.
  Key names choose the credential type (paths are relative to the env file):

  | In `.env` | Credential | Use it with |
  |---|---|---|
  | `X_USR=...` + `X_PSW=...` | usernamePassword `X` | `usernamePassword(credentialsId: 'X', ...)`, or `credentials('X')`, which sets `X_USR`/`X_PSW` |
  | `X_FILE=path` | file `X` | `file(credentialsId: 'X', variable: ...)` |
  | `X_SSH_KEY=path` (+ `X_SSH_USER`, default `git`; `X_SSH_PASSPHRASE`) | sshUserPrivateKey `X` | `sshUserPrivateKey(credentialsId: 'X', ...)`, `sshagent` |
  | anything else | secret text, ID = the key | `string(credentialsId: 'KEY', variable: ...)` |
- **Global**: `jenkins-local secret set ID` (asks for the value, or reads stdin),
  `secret list`, `secret rm ID`. Stored one file per secret in
  `~/.config/jenkins-local/secrets/` (mode 600), outside this repo.

## Commands

| Command | |
|---|---|
| `jenkins-local` | build the current repo (`-e FILE`, `--no-env`, `--keep-workspace`) |
| `jenkins-local status` | running or not, disk use, secrets, jobs (flags jobs whose repo is gone) |
| `jenkins-local prune` | delete leftover workspaces |
| `jenkins-local selftest` | build `selftest/Jenkinsfile` as a throwaway repo and check each feature (docker agent, workspace, `.env` secret, artifacts, test report, cleanup); leaves nothing behind when all pass |
| `jenkins-local start` / `stop` / `restart` / `logs` | the Jenkins container; `restart` after editing `config/` |
| `jenkins-local secret set\|list\|rm` | global secrets |

## Disk use

Bounded on purpose: workspaces are deleted after each build, jobs keep their last 20 builds
(a Jenkinsfile's own `buildDiscarder` wins), the container log is capped at 30 MB, and every
build warns when the data passes `JENKINS_LOCAL_WARN_GB` (default 5). Data lives in
`~/.local/share/jenkins-local/`; archived artifacts are under
`jobs/<repo>/branches/<branch>/builds/<n>/archive/` (the branch folder name is shortened
and suffixed by Jenkins, e.g. `feature-x.1ttbu8`) and go when their build is discarded.

## Files

| Path | |
|---|---|
| `bin/jenkins-local` | the command |
| `config/Dockerfile`, `config/plugins.txt` | the Jenkins image |
| `selftest/Jenkinsfile` | the sample project `selftest` builds |
| `~/.config/jenkins-local/secrets/` | global secrets (per machine, not in git) |
| `~/.local/share/jenkins-local/` | `JENKINS_HOME`: jobs, builds, workspaces (per machine) |

Settings: `JENKINS_LOCAL_PORT` (default 8090), `JENKINS_LOCAL_WARN_GB` (default 5).

Needs: bash, git, perl, curl, and Docker usable without sudo.
