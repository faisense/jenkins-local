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
2. Creates or updates a folder named after the repo, with a job `build` inside, from the
   `Jenkinsfile` on disk.
3. Copies the files git would commit (tracked + untracked, minus `.gitignore`d ones such as
   `.venv` and `.env`) into a fresh workspace and commits them there, so the build sees a
   normal checkout. No commit needed in your repo.
4. Runs the build, streams the log, deletes the workspace, and exits 0 on success.

## Secrets

`withCredentials([string(credentialsId: 'ID', variable: ...)])` finds secrets in two places:

- **The repo's `.env`** (default): each `KEY=value` line becomes a secret for that repo only,
  overriding a global one with the same ID. `-e FILE` uses another file; `--no-env` none.
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
`jobs/<repo>/jobs/build/builds/<n>/archive/` and go when their build is discarded.

## Files

| Path | |
|---|---|
| `bin/jenkins-local` | the command |
| `config/Dockerfile`, `config/plugins.txt` | the Jenkins image |
| `config/job.xml` | template of each repo's job |
| `selftest/Jenkinsfile` | the sample project `selftest` builds |
| `~/.config/jenkins-local/secrets/` | global secrets (per machine, not in git) |
| `~/.local/share/jenkins-local/` | `JENKINS_HOME`: jobs, builds, workspaces (per machine) |

Settings: `JENKINS_LOCAL_PORT` (default 8090), `JENKINS_LOCAL_WARN_GB` (default 5).

Needs: bash, git, rsync, perl, curl, and Docker usable without sudo.
