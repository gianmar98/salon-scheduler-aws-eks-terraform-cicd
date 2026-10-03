# `codebuild_deploypods` module

CodeBuild project that restarts the app's pods on EKS so they pull the newest image. It is
the pipeline's last stage, after BuildImage pushes to ECR.

Written directly in Terraform, starting as a copy of `codebuild_buildimage`. It does not
build images, so it has no `privileged_mode` and no ECR permissions; instead it can find the
cluster and list load balancers.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_codebuild_project.deploypods` | the project |
| `aws_iam_role.deploypods` | service role, trusted by `codebuild.amazonaws.com` |
| `aws_iam_policy.deploypods_base` + attachment | logs, artifact bucket, `eks:DescribeCluster`, `DescribeLoadBalancers` |
| `aws_iam_policy.deploypods_codeconnections` + attachment | clone GitHub through the connection |
| `aws_cloudwatch_log_group.deploypods` | `/aws/codebuild/<project>`, with retention |

No report groups and no webhook. The pipeline is the only trigger.

**IAM alone does not get this role into the cluster.** The cluster uses
`authentication_mode = "API"`, so a role can do nothing inside Kubernetes until it has an
access entry. That entry, and the network allowlist that lets CodeBuild reach the API
server, live in the `eks` module. They need the cluster, which only exists behind
`eks_enabled`. See [Wiring outside this module](#wiring-outside-this-module).

## What it runs

The recipe is `appointments-app/buildspecs/buildspec_deploypods.yml`, read from the cloned
source at build time. It is ACI's Lab 10 skeleton (see `NOTICE`):

| Phase | Command | Why |
|---|---|---|
| pre_build | `aws eks update-kubeconfig --name $EKS_CLUSTER_NAME` | point kubectl at the cluster |
| build | `kubectl rollout restart deployment appointments-deployment` | replace pods one at a time; each new one pulls the image again |
| post_build | `sleep 30`, then `aws elbv2 describe-load-balancers` | print the site's address in the build log |

The lab deletes the Deployment and re-applies `manifests/`. That does not fit here:
Terraform owns the Deployment, and the manifests are commented out. A restart leaves
Terraform's objects in place and only swaps the pods.

**A restart only deploys new code because of two settings in the `eks` module.** The
Deployment uses `image_pull_policy = "Always"`, and its tag (`eks_app_image_tag`) is one that
BuildImage re-pushes on every build. Pin the tag to a commit SHA and a restart pulls the
same old image again.

`kubectl` ships with `aws/codebuild/standard:8.0`, so the buildspec installs nothing.

## Inputs

All 11 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `deploypods_codebuild_project_name` | string | env-suffixed by the caller; also names the role, both policies, and the log group |
| `deploypods_codebuild_codeconnection_arn` | string | the GitHub connection the env layer owns |
| `deploypods_codebuild_eks_cluster_name` | string | becomes `$EKS_CLUSTER_NAME` in the build; also scopes `eks:DescribeCluster` |
| `deploypods_codebuild_artifact_bucket_name` | string | the pipeline artifact bucket this project reads its source from |
| `deploypods_codebuild_log_retention_days` | number | must be a value CloudWatch accepts; 0 = forever |
| `deploypods_codebuild_source_location` | string | `https://github.com/<owner>/<repo>`, no trailing path |
| `deploypods_codebuild_source_version` | string | branch to check out **when a build runs**, not a trigger |
| `deploypods_codebuild_buildspec` | string | path from the **repo root**, not from this module |
| `deploypods_codebuild_image` | string | managed CodeBuild image |
| `deploypods_codebuild_compute_type` | string | `BUILD_GENERAL1_SMALL` \| `MEDIUM` \| `LARGE` |
| `deploypods_codebuild_build_timeout` | number | 5–480 minutes; dev uses 10, since a restart takes about one |

## Outputs

| Name | Value |
|---|---|
| `deploypods_codebuild_project_name` | project name, used as the pipeline's `ProjectName` |
| `deploypods_codebuild_project_arn` | project ARN, scopes the pipeline role's `StartBuild` |
| `deploypods_codebuild_service_role_arn` | service role ARN, which the `eks` module gives an access entry |
| `deploypods_codebuild_log_group_name` | log group the build writes to |

## IAM

| Policy | Actions | Scope |
|---|---|---|
| base | `logs:CreateLogGroup`, `CreateLogStream`, `PutLogEvents` | this project's log group |
| base | the five `s3:*` object/bucket reads | the pipeline artifact bucket |
| base | `eks:DescribeCluster` | the one cluster ARN, built from the region, account, and cluster name |
| base | `elasticloadbalancing:DescribeLoadBalancers` | `"*"`, because the action cannot be scoped to one load balancer |
| codeconnections | `GetConnectionToken`, `GetConnection`, `UseConnection` | the connection, under both its old and new service prefixes |

`kubectl` itself needs no extra IAM. It authenticates with `aws eks get-token`, which signs a
request as the role, and EKS maps that role to its access entry.

## Wiring outside this module

Three pieces sit elsewhere because they depend on the cluster or the pipeline:

| Where | What | Without it |
|---|---|---|
| `eks/access_entry.tf` | access entry for this role + `AmazonEKSEditPolicy`, scoped to the app namespace | `kubectl` fails with `Unauthorized` |
| `eks/eks.tf` | CodeBuild's published IP ranges (`aws_ip_ranges`) added to `public_access_cidrs` | `kubectl` times out; the endpoint only accepts the operator's IP |
| `codepipeline` | the `DeployPods` stage, present only while `eks_enabled && eks_app_enabled` | nothing calls this project |

## Who triggers this project

**CodePipeline's `DeployPods` stage, and nothing else.** It runs after BuildImage, so pods
restart only after a new image is in ECR.

To run it on its own, without a push (the cluster must be up):

```bash
aws codebuild start-build --project-name deploypods-dev --region us-east-1
```

## Rolling back

`kubectl rollout undo` does **not** work here. It restores the previous pod template, but
that template names the same reused tag, which now points at the new image. Roll back
through git instead:

```bash
git revert <commit-id> --no-edit
git push
```

The pipeline rebuilds the old code and DeployPods restarts the pods onto it.

## Gotchas

- **The Deployment name is hardcoded in the buildspec.** `appointments-deployment` must match
  `eks_app_selector` in tfvars. Rename one and the restart fails with `not found`.
- **Every restart leaves an annotation on the Deployment.** `kubectl rollout restart` works by
  writing `kubectl.kubernetes.io/restartedAt` into the pod template. The `eks` module ignores
  that one key (`lifecycle.ignore_changes` in `k8s_deployment.tf`). Without it, every
  `terraform apply` after a pipeline run would delete the annotation and restart the pods
  again.
- **Opening the endpoint to CodeBuild opens it to all of CodeBuild in the region.** The
  published ranges are shared by every account. The access entry is what limits the cluster
  to this one role.
- **Renaming the project renames five other things.** The role, both policies, and the log
  group all derive from `deploypods_codebuild_project_name`.
- **The project's own `source` and `artifacts` are overridden at runtime.** CodePipeline
  forces both to type `CODEPIPELINE`, so the `GITHUB` source and `NO_ARTIFACTS` here apply
  only to direct `start-build` runs.
