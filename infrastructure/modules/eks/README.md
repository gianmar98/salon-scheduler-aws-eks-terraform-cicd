# `eks` module

A Kubernetes cluster and one managed node group, plus the two IAM roles neither can start
without, plus the two Kubernetes objects that run the application on it. The pipeline
still stops at ECR — the image is deployed from here, by `terraform apply`, not by a
pipeline stage.

## Provenance

The ACI lab never asked for a cluster to be built. It assumed one already provisioned in
the lab account, named `eks-cluster`, and asked only that it be verified with `kubectl`
and `eksctl` — no instructions, skeleton, or solution for creating one. This repository
has no pre-provisioned cluster, so everything here was researched and written from
scratch. The lab's verification commands are the only part that traces back to ACI, and
they are commands to run, not code. `NOTICE` records the same.

Written directly in Terraform from raw resources, not from
`terraform-aws-modules/eks/aws`. That module takes 200+ inputs and creates around 40
resources by default, including a KMS key and a CloudWatch log group this project does not
want. Four resources that can be read top to bottom is the better trade for a capstone.

## Cost, and the switch that controls it

**The control plane is $0.10/hour — about $73/month — whether or not anything runs on it.**
There is no free tier and no pause. Two `t3.small` spot nodes add roughly $9/month, so the
control plane is ~88% of the bill: shrinking nodes saves almost nothing, and destroying the
cluster saves nearly everything.

Hence `eks_enabled` in `terraform.tfvars`. The env layer carries `count = var.eks_enabled ? 1 : 0`
on the module block, so:

```hcl
eks_enabled = false   # then: terraform apply
```

destroys the cluster, the node group, and both roles — and nothing else. A bare
`terraform destroy` would take RDS, ECR, and the pipeline with it.

Two consequences of that `count`:

- **It had to be there before the first apply.** Adding `count` later changes every
  resource address in state and needs a `terraform state mv` per resource.
- **Anything referencing this module needs `try(module.eks[0].x, null)`**, or a `false`
  apply fails on an undefined reference. `envs/dev/outputs.tf`, `kubernetes_provider.tf`,
  and the `rds` module's EKS ingress rule all reference it, and all three use `try`.

`eks_app_enabled` is a **second** switch, gating only the Kubernetes objects. It exists
because `kubernetes_provider.tf` reads the cluster address from this module: turning
`eks_enabled` off removes that address, and Terraform is then left with a Service and a
Deployment to delete and nowhere to send the request — it fails against `localhost`.
Shutdown is therefore two applies, `eks_app_enabled = false` first. Bring-up on a cold
cluster is the mirror: both flags true in one run fails at plan with "provider
configuration depends on values that cannot be determined until apply", the same trap as
the `mysql` provider in `modules/rds`.

Re-enabling gives a **new endpoint and a new certificate**, so
`aws eks update-kubeconfig` has to be re-run every time. See
`appointments-app/COMMANDS.md`.

## What it creates

| Resource | Purpose |
|---|---|
| `aws_eks_cluster.salon_eks_cluster` | the control plane |
| `aws_eks_node_group.salon_eks_node` | the EC2 instances that run pods |
| `aws_iam_role.salon_eks_cluster_role` + 1 attachment | what EKS assumes to manage AWS resources |
| `aws_iam_role.eks_node_role` + 3 attachments | what the instances assume |
| `aws_autoscaling_group_tag.node_name` | gives launched instances a `Name` in the EC2 console |
| `aws_eks_addon.pod_identity_agent` | AWS's credential-delivery agent, one pod per node |
| `aws_iam_role.eks_app_role` | what the application pods assume |
| `aws_eks_pod_identity_association.appointments_app` | binds a Kubernetes service account to that role |
| `aws_iam_policy.eks_app_base_policy` + 1 attachment | what the application may do: scan the announcements table, open a database connection |
| `kubernetes_service_v1.appointments` | the load balancer and the stable entry point in front of the pods |
| `kubernetes_deployment_v1.appointments` | the pods themselves — image, replica count, environment |

Fifteen objects on a first apply — the three node policy attachments come from one
`for_each`, and the last two are Kubernetes objects rather than AWS ones.

## Two Kubernetes objects live here, for two different reasons

Everything else in `appointments-app/manifests/` is applied with `kubectl`. These two are
not, and the reasoning differs:

- **`kubernetes_service_v1`** is here because `type = LoadBalancer` makes Kubernetes ask
  AWS for a classic load balancer — a billable resource Terraform did not create and so
  would not destroy. Applied with `kubectl`, it outlives `eks_enabled = false` as an
  orphan with no owner. In state, destroying the cluster deletes the Service first and
  Kubernetes releases the load balancer on the way out.
- **`kubernetes_deployment_v1`** creates nothing outside the cluster and cannot be
  orphaned. It is here because its values *are* this run's outputs: `eks_app_image_uri`
  from `module.ecr`, `eks_app_db_host` from `module.rds_db`. As a manifest it carried
  `<INSERT_…>` placeholders that a human filled in after every rebuild, and the filled-in
  version would have put the AWS account ID in git.

`appointments-serviceaccount.yml` is still `kubectl`'s: it holds no generated values and
creates nothing outside the cluster. Both YAML manifests it sits beside are commented out
with a header explaining which Terraform resource replaced them.

`eks_app_selector` is the single value three places must agree on — the Service's
selector, the Deployment's `match_labels`, and the pod template's label. A mismatch is not
an error: the Service simply has no backends and the URL times out.

## The two IAM roles are not interchangeable

The trust principals differ, and getting them backwards means instances launch and never
join:

- **Cluster role** trusts `eks.amazonaws.com` — the EKS *service* assumes it to manage AWS
  resources on your behalf. One policy: `AmazonEKSClusterPolicy`.
- **Node role** trusts `ec2.amazonaws.com` — the *instances themselves* assume it.

The node role's three policies each have a distinct failure mode, and none of the errors
mention IAM:

| Policy | Missing it means |
|---|---|
| `AmazonEKSWorkerNodePolicy` | instance boots fine, never appears in `kubectl get nodes` |
| `AmazonEKS_CNI_Policy` | node joins, every pod stuck in `ContainerCreating` |
| `AmazonEC2ContainerRegistryReadOnly` | pods scheduled, images fail with `ImagePullBackOff` |

The third is what ties this module to the rest of the project — it is how a node pulls the
image `codebuild_buildimage` pushes to ECR.

## Pod Identity is how the application gets AWS credentials

A third role, with a third trust principal: `pods.eks.amazonaws.com`. The cluster and node
roles are assumed by AWS services; this one is assumed by *the application*, so Django can
call DynamoDB and RDS without an access key baked into the image.

Three objects, and all three are required:

- **`aws_eks_addon.pod_identity_agent`** runs on every node and is what actually hands
  credentials to a pod. It carries a `depends_on` for the node group — created before any
  node exists it has nowhere to run and the addon reports `DEGRADED`.
- **`aws_iam_role.eks_app_role`** is the identity, carrying one policy with exactly two
  statements: `dynamodb:Scan` on the announcements table, and `rds-db:connect` on one
  database user. `views.py` makes one DynamoDB call and one database connection; nothing
  else is granted.
- **`aws_eks_pod_identity_association.appointments_app`** maps a namespace plus a service
  account name to that role.

**The trust policy needs `sts:TagSession` as well as `sts:AssumeRole`.** Pod Identity tags
each session with the namespace and service account it came from, so without permission to
tag it cannot assume at all. Everything applies cleanly; the failure surfaces later, at
runtime, in the pod.

The association stores the service account as a **string** and never resolves it. Terraform
applies successfully whether or not that account exists in the cluster, and a typo is not
an error anywhere — the pod simply receives no credentials. `eks_app_service_account` must
match `service_account_name` in `k8s_deployment.tf` and the `name` in
`appointments-app/manifests/appointments-serviceaccount.yml` exactly. Both of those read
the same variable or the same literal; the ServiceAccount object itself is still applied
with `kubectl`, not Terraform.

### The `rds-db:connect` ARN is not the instance ARN

`rds-db` is a separate service namespace from `rds`. The instance ARN
(`arn:aws:rds:…:db:salon-db-dev`) authorizes *managing* the instance; `rds-db:connect`
authorizes *logging in as one database user*, so the ARN has to name that user:

```
arn:aws:rds-db:<region>:<account>:dbuser:<resource_id>/<username>
```

It is assembled in the env layer, not here, because it needs the account ID and region and
this repository keeps account IDs out of committed `.tf`. `<resource_id>` is
`module.rds_db.appointments_db_resource_id` — the immutable `db-XXXX` value, not the
identifier, so renaming the instance cannot break or misdirect the grant.

Nothing validates any of it. A wrong account attribute (`user_id` in place of `account_id`
is the easy mistake) still produces a well-formed ARN, still plans and applies, and
surfaces much later as the application failing to reach the database.

**`rds-db:connect` only grants permission to request a token.** The database must also have
a user created `IDENTIFIED WITH AWSAuthenticationPlugin` before that token is accepted —
that half lives in the `rds` module, not here.

## `depends_on` is load-bearing on both resources

Terraform sees `aws_iam_role.x.arn` and orders the **role** first. It has no idea the
role's **policy attachments** matter. Without the explicit `depends_on` it can legally
create the cluster against a role that is still empty.

The symptom is an intermittent create failure, and — worse — a *destroy* that fails,
because EKS cannot clean up its network interfaces once the CNI permissions are gone.
Neither error mentions IAM. Both `aws_eks_cluster` and `aws_eks_node_group` carry one.

## Networking

Default VPC, public subnets, no NAT gateway. A private-subnet cluster would add roughly
$32/month in NAT charges alone and buys nothing while there is no workload.

Subnets come from `data.aws_subnets.eks_subnets` in the env layer, filtered by
**availability-zone ID**, not by the `us-east-1a/b/c` letters. AWS shuffles the
letter-to-datacenter mapping per account, so the same letter is different hardware in a
different account. `use1-az3` is excluded deliberately: EKS control planes cannot run
there.

### The public/private endpoint trap

`public_access_cidrs` is narrowed to the IP of whoever runs `apply`, resolved through
`data.http.myip` — the same pattern as `modules/rds`. **That narrowing requires
`endpoint_private_access = true` alongside it**, and this is the single easiest way to
break this module.

Nodes live inside the VPC but reach the API server the same way anything else does. With
only the public endpoint open and a one-IP allowlist, the nodes' own addresses are not on
that list, so they are refused, retry forever, and the node group sits in `CREATING` until
its 60-minute timeout. Nothing in the output mentions networking, the EC2 instances look
perfectly healthy, and `health.issues` on the node group stays empty.

Left at the default `0.0.0.0/0`, nodes join fine — which is why this only bites once the
cluster is *tightened*.

`public_access_cidrs` updates in place, no cluster replacement, so widening or narrowing it
later is a normal apply. A changed home IP locks this machine out until the env layer is
re-applied — same trade as the RDS security group.

## `ami_type` is deliberately not a tfvars dial

`AL2023_x86_64_STANDARD` is hardcoded because it is determined by the instance family, not
chosen independently. `t3` is x86; moving to `t4g` (Graviton/ARM) requires changing
`ami_type` to `AL2023_ARM_64_STANDARD` in the same edit or nodes boot and never join. Two
settings that must move together are safer as one constant with a comment — the same
reasoning as `privileged_mode` in `codebuild_buildimage`.

`eks_node_instance_types` carries a validation that it is non-empty, but nothing can check
the architecture matches. Keep every entry in the same family.

## Inputs

All 25 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `eks_cluster_name` | string | env-suffixed by the caller |
| `eks_subnets_ids` | list(string) | ≥ 2 AZs, enforced |
| `eks_kubernetes_version` | string | pin it, or AWS picks the moving default |
| `eks_node_group_name` | string | env-suffixed by the caller |
| `eks_node_capacity_type` | string | `SPOT` \| `ON_DEMAND`, enforced |
| `eks_node_instance_types` | list(string) | ≥ 1 entry; all must match `ami_type`'s architecture |
| `eks_node_disk_size` | number | GiB per node |
| `eks_node_desired_size` | number | nodes now |
| `eks_node_min_size` | number | lower bound |
| `eks_node_max_size` | number | upper bound |
| `eks_app_namespace` | string | namespace both Kubernetes objects are created in |
| `eks_app_service_account` | string | must match the ServiceAccount manifest's `name` |
| `eks_app_enabled` | bool | gates the Service and Deployment; turn off and apply **before** `eks_enabled` |
| `eks_app_service_name` | string | the Service's name in the cluster |
| `eks_app_selector` | string | the pod label — Service selector, Deployment selector, and pod template all use it |
| `eks_app_container_port` | number | must match the Dockerfile's `EXPOSE` and `CMD` |
| `eks_app_replicas` | number | pod copies to keep running |
| `eks_app_image_uri` | string | computed in the env layer from the `ecr` module's output — keeps the account ID derived |
| `eks_app_image_tag` | string | `latest` never changes, so Terraform will not redeploy on a new push; a commit SHA will |
| `eks_app_aws_region` | string | computed in the env layer; boto3 reads it for DynamoDB |
| `eks_app_db_host` | string | computed in the env layer from the `rds` module's output |
| `eks_app_db_user` | string | the IAM-authenticated MySQL user `modules/rds` creates |
| `eks_app_db_name` | string | database Django connects to |
| `eks_app_dynamodb_announcements_table_arn` | string | computed in the env layer from the `dynamodb` module's output |
| `eks_app_rds_db_user_arn` | string | computed in the env layer; `rds-db` namespace, not `rds` |

`eks_subnets_ids` is computed from a data source in the env layer and so never passes
through `envs/dev/variables.tf` or `terraform.tfvars` — the same shape as
`appointments_db_vpc_id` on the `rds` module. The two ARN inputs are computed the same way,
from other modules' outputs, and are likewise absent from `terraform.tfvars`.

Four of the Deployment's inputs are computed the same way — `eks_app_image_uri`,
`eks_app_aws_region`, `eks_app_db_host`, and `eks_app_db_user`. That is the point of
moving the Deployment into Terraform: the two values that used to be pasted in by hand
after every rebuild are now derived, and the account ID never reaches a committed file.
Only `eks_app_replicas` and `eks_app_image_tag` are real `terraform.tfvars` dials.

With no autoscaler installed, `min`/`max` are guardrails only: `desired` never changes on
its own.

## Outputs

Five.

`cluster_endpoint` and `cluster_certificate_authority_data` exist for one consumer:
`envs/dev/kubernetes_provider.tf`. They are the API address and the CA cert to verify it
against — the same two values `aws eks update-kubeconfig` writes into `~/.kube/config`.
Both change on every rebuild, which is why nothing caches them.

`app_url` is the load balancer's hostname with `http://` in front, read off the Service's
status. The Service sets `wait_for_load_balancer = true` so apply blocks until AWS reports
an endpoint and this is never empty. It is `http`, not `https` — a classic load balancer
with no certificate.

`cluster_security_group_id` is the security group EKS creates and attaches to the managed
nodes. `modules/rds` takes it as an allowed inbound source, so pods can reach the database
without anyone tracking node IP addresses — nodes are replaced routinely and their addresses
change, group membership does not.

`kubeconfig_command` is the `aws eks update-kubeconfig` line with the region and cluster
name already filled in. The env layer re-exports it as `eks_kubeconfig_command`, wrapped in
`try(module.eks[0].kubeconfig_command, null)` so it returns `null` rather than erroring when
`eks_enabled = false` — the `count` note above.

It is an output rather than a `local-exec` provisioner on purpose. A provisioner runs only
on *create*, writes machine-local state Terraform cannot see or clean up, and taints the
cluster if it fails — a missing `aws` CLI would trigger a 20-minute rebuild. Printing the
command and running it by hand costs nothing and breaks nothing.

The region comes from a module-local `data "aws_region" "current"`, matching
`codebuild_unittest` and `codebuild_buildimage`. A data source cannot be passed across a
module boundary.

## Access

`authentication_mode = "API"` means Kubernetes permissions come only from IAM access
entries. The alternative, `API_AND_CONFIG_MAP`, also honours the legacy in-cluster
`aws-auth` ConfigMap — two places to check when someone cannot connect.

`bootstrap_cluster_creator_admin_permissions = true` grants cluster-admin to the IAM
principal that runs `terraform apply`, and is the only reason `kubectl` works with no
further setup. It applies **at creation only** and forces a cluster replacement if changed.

Two things follow:

- **The AWS console's Kubernetes tabs show `Unauthorized`** when browsed as a different
  principal (root, another user) than the one that applied. The cluster is fine;
  `kubectl` from the terminal that ran apply works. Fixing the console needs an
  `aws_eks_access_entry`.
- **Applying from CI later will not inherit access.** A CodeBuild role would have zero
  Kubernetes permissions and need an explicit access entry.

## Known gaps

- **`AmazonEKS_CNI_Policy` is on the node role, so every pod inherits it.** Only the
  `aws-node` DaemonSet needs `ec2:CreateNetworkInterface` / `AttachNetworkInterface`. The
  hardening is Pod Identity: add the `eks-pod-identity-agent` addon, a role trusted by
  `pods.eks.amazonaws.com`, and an association for `kube-system/aws-node`, then drop the
  policy from the node role. Deferred on purpose — it introduces a bootstrap ordering
  requirement (cluster → addon → association → node group) whose failure mode is a node
  group that times out after 15 minutes with an error pointing nowhere near IAM.
- **No `aws_eks_addon` resources.** `bootstrap_self_managed_addons` defaults to `true`, so
  EKS installs the VPC CNI, CoreDNS, and kube-proxy itself, outside Terraform. They work;
  their versions just cannot be pinned or upgraded from here.
- **No pipeline deploy stage.** The application is deployed by `terraform apply` from a
  laptop, not by CodePipeline. With `eks_app_image_tag = "latest"` a new image pushed to
  ECR produces no Terraform diff, so picking it up is `kubectl rollout restart deployment
  appointments-deployment`. Setting the tag to a commit SHA makes the deploy explicit but
  moves the bump to a hand edit.
- **No readiness probe on the Deployment.** A pod counts as ready the moment the container
  starts, so during a rolling update the load balancer can route to a pod before Django is
  serving. Tolerable here because the health check is TCP and `runserver` binds quickly.
- **No resource requests or limits.** Two pods on two `t3.small` nodes with nothing else
  scheduled, so the scheduler has no packing decision to get wrong.
- **`runserver` in production.** Django's development server, from the ACI Dockerfile's
  `CMD`. Single-threaded and explicitly not for production use; gunicorn is the fix.
- **No OIDC provider, no IRSA.** Pod Identity covers what the application needs.
- **`storage_encrypted` and secrets encryption are untouched.** EKS encrypts etcd with an
  AWS-managed key by default; a customer-managed KMS key is the upgrade, at ~$1/month.

## Gotchas

- **`instance_types` is plural and takes a list.** A single type still needs brackets.
- **Listing several spot types only helps if they are actually equivalent.** `t3.small`
  and `t2.small` differ in vCPU (2 vs 1); `t3.small` and `t3a.small` differ in max pods
  (11 vs 8, from 3 ENIs vs 2). Mixing them means node capacity varies by which one AWS
  happened to have. One type keeps every node identical.
- **`t3.small` caps at 11 pods per node.** Every pod takes a real VPC IP, and the instance
  can only hold so many network interfaces. System pods eat into that. `t3.medium` is 17.
- **Node group creation takes 8-10 minutes on top of the cluster's 8-9.** A first apply is
  ~20 minutes. Slow is normal; *stuck* is the endpoint trap above.
- **`aws_autoscaling_group_tag` only affects instances launched after it exists.** Nodes
  running when it was added stay unnamed until replaced. Tags on `aws_eks_node_group`
  itself tag the node group object, **not** the EC2 instances.
- **SSM Session Manager does not work on these nodes.** The node role has no
  `AmazonSSMManagedInstanceCore`, so the instances never register with SSM and the console's
  Connect button has nothing to attach to. Adding that ARN to the `for_each` list fixes it
  and replaces the nodes.
- **`eksctl get cluster` reports `EKSCTL CREATED: False`.** Correct — Terraform built it.
- **Terraform will not adopt an object `kubectl` already created.** A Deployment or
  Service of the same name in the same namespace makes the apply fail with `already
  exists`; Terraform has no state for it and will not take it over. Delete it first
  (`kubectl delete deployment appointments-deployment`) or `terraform import` it.
- **A stale kubeconfig looks like a dead cluster.** After a rebuild, `kubectl` reports
  `no such host` against the previous endpoint. That is the local config, not the cluster
  — re-run the `eks_kubeconfig_command` output.
- **The Service's `selector` is a plain map; the Deployment's is a `selector` block with
  `match_labels`.** The same idea with two different syntaxes, and pasting one into the
  other validates as far as HCL and fails in the provider.