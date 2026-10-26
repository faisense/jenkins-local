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
| `jenkins-local prune` | delete leftover workspaces and downloaded tools |
| `jenkins-local selftest [--tools]` | build `selftest/Jenkinsfile` as a throwaway repo and check each feature (docker agent, checkout, secrets, labels, shared library, artifacts, test report, cleanup); `--tools` also installs and runs a JDK and Maven (~200 MB, once); leaves nothing behind when all pass |
| `jenkins-local start` / `stop` / `restart` / `logs` | the Jenkins container; `restart` after editing `config/` |
| `jenkins-local secret set\|list\|rm` | global secrets |
| `jenkins-local lib add NAME PATH` / `lib list` / `lib rm NAME` | shared libraries (below) |
| `jenkins-local tool add maven\|jdk NAME VERSION` / `tool list` / `tool rm maven\|jdk NAME` | build tools (below) |
| `jenkins-local plugins sync URL` / `plugins unsync` / `plugins list` | match a server's Jenkins and plugin versions (below) |

## Shared libraries

`jenkins-local lib add pipeline-utils ~/src/pipeline-utils` registers a local git repo as the
library `pipeline-utils`. A Jenkinsfile that loads it (`@Library('pipeline-utils')`,
`@Library('pipeline-utils@v2') _`, `library 'pipeline-utils'`) gets that repo's working
tree, uncommitted changes included, whatever version it asks for: each build snapshots it
like the repo itself and defines it as a global library. A library the Jenkinsfile loads but
that isn't registered is reported before the build (which then fails on it).
`library(identifier: ..., retriever: ...)` brings its own source and is left alone.

## Build tools

`tools { maven '...'; jdk '...' }` and `tool name: '...', type: 'maven'` need tool
definitions. A tool the Jenkinsfile names but Jenkins lacks is defined from its name when
that says enough: a Maven name with a version (`'3.9.9'`, `'maven-3.9.9'`) installs that
version from Apache, a JDK name with a major (`'jdk21'`, `'temurin-17'`) the latest Eclipse
Temurin release of it. Otherwise the build says what to run, e.g.
`jenkins-local tool add maven M3 3.9.9` or `jenkins-local tool add jdk java jdk-21.0.5+11`.
Tools are downloaded on first use into `~/.local/share/jenkins-local/tools/` (`prune`
clears them). Only Maven and JDK are supported.

`tools { }` applies only to stages that don't run in a docker agent, as on any Jenkins:
Jenkins can't set `PATH` inside a container (and a downloaded JDK needs glibc).

## Plugins

The image installs `config/plugins.txt` (what jenkins-local needs: configuration-as-code,
Pipeline, Docker Pipeline, git, credentials, JUnit, Temurin installer) on Jenkins LTS.

- **Match your CI server:** `jenkins-local plugins sync https://ci.example.com` records the
  server's Jenkins version and its active plugins' exact versions; `jenkins-local restart`
  then builds the image from that Jenkins version with those plugins pinned (plus the ones
  above). Set `JENKINS_LOCAL_SERVER_AUTH=user:api-token` if the server needs a login.
  `plugins unsync` goes back to LTS. A restart whose image fails to build keeps the running
  Jenkins.
- **Per project:** a `jenkins-plugins.txt` in the repo (same format: `name` or
  `name:version`, `#` comments) lists plugins its Jenkinsfile needs; the missing ones are
  installed before its build (Jenkins restarts only if one of them requires it) and stay
  installed.
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
