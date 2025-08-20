# Upgrade Go Version Playbook

**Description:** This is a playbook to upgrade the Go version of a golang repo to the target version.

**Example:** `upgrade go version to 1.23`

## Parameters

- **target_go_version**: Target Go version

For a repo, upgrade go version means we need to change the following files:

- go.mod
  - After upgrade the go version here, remember to go mod tidy, and if there is vendor directory, remember to run `go mod vendor`
- Dockerfiles: there are multiple Dockerfiles in the repo, usually in the root directory of the repo, sometime in the `build` or `cmd` directory
  - Sometime we use internal images as the builder image in Dockerfile, for example `brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_1.23`, in this case, the go version is `1.23`, and when you upgrade, upgrade this field as well.
- .github/workflows: there are multiple yaml files in the repo, usually in the `.github/workflows` directory

Steps:

- Run `make build` to check whether there are any errors
- If any error occurs, notify the user with the error message, and stop the task waiting for user's next instruction.
- If no error occurs, deliver the code changes to github.
  - The branch name should be like `upgrade-go-version-to-{{target_go_version}}`.
  - The PR title should be concise, and the PR description should be detailed.
