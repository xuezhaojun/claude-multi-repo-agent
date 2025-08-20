# Bump Up Package Version Playbook

**Description:** This is a playbook to bump up the golang dependencies of the specified package to the target version.

**Example:** `bump up golang.org/x/exp to v0.13.1`

## Parameters

- **package_name**: Name of the package to bump
- **target_version**: Target version to bump to

## Steps

- Run `go get {{package_name}}@{{target_version}}` to bump the dependency.
- If there is vendor in the project, run `go mod tidy && go mod vendor` and if there is not, only run `go mod tidy`
- Review the Makefile, find the make command that related to `go build` and run it. If there is no such command, run `go build` under the `cmd` directory in that repo.
  - If there is no Makefile, run `go build` under the `cmd` directory in that repo.
- If no error occurs, mark the task as done.
- If there is error, Try to fix it with the error message and build again, keep doing it until there is no error or user give up.
