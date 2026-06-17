# V1 Notes - No Kubernetes

This folder contains the initial no-Kubernetes version of the project.

It was restored from the initial Git commit:

```text
292bd95 first commit
```

## Purpose

Use this version if the first implementation should start without Kubernetes.

The V1 model is based on:

- GitLab CI/CD.
- Docker image with Prowler CLI.
- Bash/Python scripts.
- AWS target account role assumption.
- Optional S3 report storage.
- No Prowler App.
- No Postgres.
- No Valkey.
- No Kubernetes CronJobs.

## Suggested Usage

If you want to implement V1 first, create a separate GitLab branch and use the contents of this folder as the project root for that branch.

Example:

```bash
git checkout -b v1-no-kubernetes
```

Then move/copy this folder's contents to the branch root as needed.

## Relationship With V2

The repository root currently represents V2:

```text
Prowler App on Kubernetes
Postgres external
Valkey in Helm
IRSA and target AWS roles
Kubernetes CronJobs
VPN/internal access
```

This folder is kept only as a separated reference/base for a V1 branch.

