# `eks` module

A Kubernetes cluster and one managed node group, plus the two IAM roles neither can start
without, plus the Kubernetes objects that run the application on it, plus the AWS Load
Balancer Controller that puts an Application Load Balancer in front of them. `terraform
apply` creates the app's objects here; after that, the pipeline's DeployPods stage restarts
the pods onto each new image.

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

The load balancer work follows ACI Lab 9, which installs the controller with the `helm`
CLI and applies an Ingress manifest with `kubectl`. Here both are Terraform resources —
`helm_release.alb_controller` and `kubernetes_ingress_v1.appointments` — and the Ingress
carries the same field values the lab's manifest specified. Two things differ from the lab:
the lab's IAM policy was pre-attached in its account, so this module vendors the upstream
policy file (see `NOTICE`); and the lab switches the Service to `NodePort`, while this one
is `ClusterIP`, because `target-type: ip` sends ALB traffic straight to pod IPs and never
touches a node port.

## Cost, and the switch that controls it

**The control plane is $0.10/hour — about $73/month — whether or not anything runs on it.**
There is no free tier and no pause. Two `t3.small` spot nodes add roughly $9/month, so the
control plane is ~88% of the bill: shrinking nodes saves almost nothing, and destroying the
cluster saves nearly everything. The ALB adds about $16/month ($0.0225/hour plus usage) and
goes away with `eks_app_enabled = false`.

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
  `helm_provider.tf`, and the `rds` module's EKS ingress rule all reference it, and all
  four use `try`.

`eks_app_enabled` is a **second** switch, gating everything that lives inside the cluster —
the ServiceAccount, Service, Deployment, Ingress, and the controller's Helm release. It
exists because `kubernetes_provider.tf` and `helm_provider.tf` read the cluster address from
this module: turning `eks_enabled` off removes that address, and Terraform is then left with
objects to delete and nowhere to send the request — it fails against `localhost`.
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
| `kubernetes_service_account_v1.appointments` | the identity the pods run as, and what Pod Identity maps to the app role |
| `kubernetes_service_v1.appointments` | the stable in-cluster address (`ClusterIP`) the Ingress routes to |
| `kubernetes_deployment_v1.appointments` | the pods themselves — image, replica count, environment |
| `aws_ec2_tag.subnet_elb_role` / `subnet_cluster` | one pair per subnet — how the controller finds where to put the ALB |
| `aws_iam_role.alb_controller_role` + policy + attachment | what the load balancer controller may do in AWS |
| `aws_eks_pod_identity_association.alb_controller_association` | binds the controller's service account to that role |
| `helm_release.alb_controller` | the AWS Load Balancer Controller itself |
| `kubernetes_ingress_v1.appointments` | the request the controller turns into a real ALB |
| `aws_eks_access_entry.eks_entry` + `aws_eks_access_policy_association.eks_entry` | lets the pipeline's DeployPods CodeBuild role restart the app; Edit on the app namespace only |

29 objects on a first apply with three subnets — the node policy attachments and the
subnet tags come from `for_each`. The four Kubernetes objects and the Helm release are the
five `eks_app_enabled` gates; everything else follows `eks_enabled` alone.

## Four Kubernetes objects live here, for different reasons

Every manifest in `appointments-app/manifests/` is commented out; all of them are
Terraform resources now, and the reasoning differs for each:

- **`kubernetes_ingress_v1`** is here because it makes the controller create an ALB — a
  billable AWS resource Terraform did not create directly and so would not destroy.
  Applied with `kubectl`, it outlives `eks_enabled = false` as an orphan with no owner. In
  state, shutdown deletes the Ingress first and the controller removes the ALB on the way
  out.
- **`kubernetes_service_v1`** carried that same argument until Lab 9, when it was
  `type = LoadBalancer` and asked AWS for a Classic Load Balancer itself. It is `ClusterIP`
  now and creates nothing outside the cluster, but the Ingress names it as its backend and
  both share the `eks_app_enabled` lifecycle, so it stays beside it.
- **`kubernetes_deployment_v1`** creates nothing outside the cluster and cannot be
  orphaned. It is here because its values *are* this run's outputs: `eks_app_image_uri`
  from `module.ecr`, `eks_app_db_host` from `module.rds_db`. As a manifest it carried
  `<INSERT_…>` placeholders that a human filled in after every rebuild, and the filled-in
  version would have put the AWS account ID in git.
- **`kubernetes_service_account_v1`** holds no generated values and creates nothing
  outside the cluster, so it was the one manifest left to `kubectl` — until a cold
  rebuild proved that wrong. Nothing runs without it: the admission controller rejects
  every pod whose `serviceAccountName` does not resolve, so the Deployment sits at 0 of 2
  replicas until `wait_for_rollout` errors ten minutes later. A "run this once first"
  prerequisite is what this project does not allow, so Terraform owns it.

The Deployment's `depends_on` on the ServiceAccount is not optional —
`service_account_name` is a plain string read from a variable, so Terraform has no way to
infer the ordering and will otherwise create both at once.

`eks_app_selector` is the single value three places must agree on — the Service's
selector, the Deployment's `match_labels`, and the pod template's label. A mismatch is not
an error: the Service simply has no backends, the ALB has no targets, and the URL returns
`503`.

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
match `service_account_name` in `k8s_deployment.tf` and `metadata.name` in
`k8s_service_account.tf` exactly. All three read the same variable, so a typo is not
reachable — but only because the ServiceAccount is a Terraform resource now.

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

## The load balancer controller builds the ALB, not Terraform

An Ingress is only a written request: "an internet-facing load balancer that sends `/` to
this Service." Kubernetes itself does nothing with it. The AWS Load Balancer Controller —
two pods in `kube-system`, installed by `helm_release.alb_controller` — watches for Ingress
objects and calls the AWS API to create, update, or delete the matching ALB, target group,
and security groups. It also watches the pods, so the ALB's target list follows every
rollout. None of that is in Terraform state; the Ingress is.

The controller gets AWS credentials the same way the app does — its own role, trusted by
`pods.eks.amazonaws.com`, matched by an association on `kube-system` plus the service
account name the chart creates. It is a **separate** role on purpose: the vendored policy
grants ~80 actions across ELB, EC2, ACM, WAF and Shield, mostly on `*`, while the app role
has two. A compromised app pod should not be able to delete load balancers.

Things that are easy to get wrong here:

- **`vpcId` and `region` are passed to the chart explicitly.** The controller otherwise
  discovers them from the EC2 instance metadata service, which these nodes do not let pods
  reach. The symptom is both pods in `CrashLoopBackOff` with `failed to get VPC ID ...
  context deadline exceeded` in the logs, and the apply failing on the Helm rollout wait.
  `eks_vpc_id` exists only for this.
- **The service account name is a string on both sides.** The chart creates the account
  from `serviceAccount.name`, and the association matches on
  `eks_alb_controller_service_account`. Both read the same variable; if they ever diverge,
  everything applies and the controller simply has no credentials.
- **The Ingress must be deleted while the controller is still running.** The controller
  puts a finalizer on each Ingress it manages and only it can remove it. Uninstall the
  controller first and the Ingress delete hangs forever while the ALB stays behind,
  billing. The Ingress's `depends_on` on the Helm release is what orders shutdown
  correctly.
- **Helm's record of the install lives in the cluster**, as a secret named
  `sh.helm.release.v1.<name>.v<revision>` in `kube-system`, not in the AWS console — the
  controller is not an EKS add-on.

The chart version (`eks_alb_controller_chart_version`) and the vendored policy file's
version must move together; a newer controller can call APIs the older policy never
granted.

## `depends_on` is load-bearing in five places

Terraform sees `aws_iam_role.x.arn` and orders the **role** first. It has no idea the
role's **policy attachments** matter. Without the explicit `depends_on` it can legally
create the cluster against a role that is still empty.

The symptom is an intermittent create failure, and — worse — a *destroy* that fails,
because EKS cannot clean up its network interfaces once the CNI permissions are gone.
Neither error mentions IAM. Both `aws_eks_cluster` and `aws_eks_node_group` carry one.

The third is `kubernetes_deployment_v1` on `kubernetes_service_account_v1`, for the same
class of reason: `service_account_name` is a string read from a variable, not a reference
to the resource, so nothing in the graph connects them.

The fourth is `helm_release.alb_controller` on the node group and the controller's Pod
Identity association: its pods need somewhere to run, and credentials the moment they
start, or the rollout wait fails.

The fifth is `kubernetes_ingress_v1` on the Helm release. On bring-up it keeps the Ingress
from reaching the controller's admission webhook before its pods are ready (`no endpoints
available for service aws-load-balancer-webhook-service`); on shutdown it reverses, so the
Ingress is deleted while the controller can still remove its finalizer and the ALB.

## Networking

Default VPC, public subnets, no NAT gateway. A private-subnet cluster would add roughly
$32/month in NAT charges alone and buys nothing while there is no workload.

Subnets come from `data.aws_subnets.eks_subnets` in the env layer, filtered by
**availability-zone ID**, not by the `us-east-1a/b/c` letters. AWS shuffles the
letter-to-datacenter mapping per account, so the same letter is different hardware in a
different account. `use1-az3` is excluded deliberately: EKS control planes cannot run
there.

`subnet_tags.tf` tags those subnets for the load balancer controller:
`kubernetes.io/role/elb = 1` marks a subnet as a valid home for an internet-facing ALB, and
`kubernetes.io/cluster/<name> = shared` says this cluster may use it. Without them the
controller finds no subnets and the Ingress never gets an address. The subnets belong to
the default VPC, not to Terraform — only the tags are managed, so destroying the cluster
removes the tags and leaves the subnets.

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

The allowlist also carries **CodeBuild's published IP ranges** for the region, looked up with
`data "aws_ip_ranges"` (three `/28`s in `us-east-1`). The pipeline's DeployPods stage runs
`kubectl` from CodeBuild, which sits outside the VPC on AWS-owned addresses; without them it
times out reaching the API server. Those ranges are shared by every CodeBuild user in the
region, so the network check now admits more than one machine — the access entry is what
restricts the cluster to the one role.

## `ami_type` is deliberately not a tfvars dial

`AL2023_x86_64_STANDARD` is hardcoded because it is determined by the instance family, not
chosen independently. `t3` is x86; moving to `t4g` (Graviton/ARM) requires changing
`ami_type` to `AL2023_ARM_64_STANDARD` in the same edit or nodes boot and never join. Two
settings that must move together are safer as one constant with a comment — the same
reasoning as `privileged_mode` in `codebuild_buildimage`.

`eks_node_instance_types` carries a validation that it is non-empty, but nothing can check
the architecture matches. Keep every entry in the same family.

## Inputs

All 33 are supplied by the env layer; validation lives here, not there.

| Name | Type | Note |
|---|---|---|
| `eks_cluster_name` | string | env-suffixed by the caller |
| `eks_subnets_ids` | list(string) | ≥ 2 AZs, enforced |
| `eks_vpc_id` | string | computed in the env layer from `data.aws_vpc.default`; passed to the controller, which cannot discover it |
| `eks_kubernetes_version` | string | pin it, or AWS picks the moving default |
| `eks_node_group_name` | string | env-suffixed by the caller |
| `eks_node_capacity_type` | string | `SPOT` \| `ON_DEMAND`, enforced |
| `eks_node_instance_types` | list(string) | ≥ 1 entry; all must match `ami_type`'s architecture |
| `eks_node_disk_size` | number | GiB per node |
| `eks_node_desired_size` | number | nodes now |
| `eks_node_min_size` | number | lower bound |
| `eks_node_max_size` | number | upper bound |
| `eks_app_namespace` | string | namespace the app's Kubernetes objects are created in |
| `eks_app_service_account` | string | must match the ServiceAccount manifest's `name` |
| `eks_app_enabled` | bool | gates the ServiceAccount, Service, Deployment, Ingress, and the controller's Helm release; turn off and apply **before** `eks_enabled` |
| `eks_app_service_name` | string | the Service's name in the cluster — the Ingress's backend points at it |
| `eks_app_ingress_name` | string | the Ingress's name in the cluster |
| `eks_app_selector` | string | the pod label — Service selector, Deployment selector, and pod template all use it |
| `eks_app_container_port` | number | must match the Dockerfile's `EXPOSE` and `CMD` |
| `eks_app_replicas` | number | pod copies to keep running |
| `eks_app_image_uri` | string | computed in the env layer from the `ecr` module's output — keeps the account ID derived |
| `eks_app_image_tag` | string | must be a tag BuildImage re-pushes every build (e.g. `latest`), or the pipeline's restart pulls a stale image |
| `eks_app_change_cause` | string | the `kubernetes.io/change-cause` annotation — what `kubectl rollout history` prints for the revision |
| `eks_app_aws_region` | string | computed in the env layer; boto3 reads it for DynamoDB |
| `eks_app_db_host` | string | computed in the env layer from the `rds` module's output |
| `eks_app_db_user` | string | the IAM-authenticated MySQL user `modules/rds` creates |
| `eks_app_db_name` | string | database Django connects to |
| `eks_app_dynamodb_announcements_table_arn` | string | computed in the env layer from the `dynamodb` module's output |
| `eks_app_rds_db_user_arn` | string | computed in the env layer; `rds-db` namespace, not `rds` |
| `eks_alb_controller_name` | string | the Helm release name — what `helm list` shows |
| `eks_alb_controller_namespace` | string | `kube-system`; also the namespace the Pod Identity association matches |
| `eks_alb_controller_service_account` | string | the chart creates it and the association matches it — one variable feeds both |
| `eks_alb_controller_chart_version` | string | pinned; keep in step with the vendored IAM policy's version |
| `eks_deploy_role_arn` | string | computed in the env layer from `codebuild_deploypods`'s output; the role the access entry admits |

`eks_subnets_ids` and `eks_vpc_id` are computed from data sources in the env layer and so never pass
through `envs/dev/variables.tf` or `terraform.tfvars` — the same shape as
`appointments_db_vpc_id` on the `rds` module. The three ARN inputs are computed the same way,
from other modules' outputs, and are likewise absent from `terraform.tfvars`.

Four of the Deployment's inputs are computed the same way — `eks_app_image_uri`,
`eks_app_aws_region`, `eks_app_db_host`, and `eks_app_db_user`. That is the point of
moving the Deployment into Terraform: the two values that used to be pasted in by hand
after every rebuild are now derived, and the account ID never reaches a committed file.
Only `eks_app_replicas`, `eks_app_image_tag`, and `eks_app_change_cause` are real
`terraform.tfvars` dials. The last two move together: the tag is what changes the pod
template and therefore creates a revision, and the change-cause is what labels it in
`kubectl rollout history`. It is a declared input rather than a `kubectl annotate` call
because Terraform strips annotations it does not manage on the next apply.

One annotation is exempt. `kubectl rollout restart`, which the pipeline's DeployPods stage
runs on every push, works by writing `kubectl.kubernetes.io/restartedAt` into the pod
template. The Deployment's `lifecycle.ignore_changes` names that single key, so Terraform
neither strips it nor plans a diff for it. Without the exemption, every apply after a
pipeline run would delete the annotation, and deleting it is itself a pod-template change
that restarts the pods again.

With no autoscaler installed, `min`/`max` are guardrails only: `desired` never changes on
its own.

## Outputs

Five.

`cluster_endpoint` and `cluster_certificate_authority_data` exist for two consumers:
`envs/dev/kubernetes_provider.tf` and `envs/dev/helm_provider.tf`. They are the API address
and the CA cert to verify it against — the same two values `aws eks update-kubeconfig`
writes into `~/.kube/config`. Both change on every rebuild, which is why nothing caches
them.

`app_url` is the ALB's hostname with `http://` in front, read off the Ingress's status. The
Ingress sets `wait_for_load_balancer = true` so apply blocks the 2–4 minutes the controller
takes to build the ALB, and this is never empty. It is `http`, not `https` — the ALB has one
listener on port 80 and no certificate. The page can still take a minute or two after apply
to load, while the ALB health-checks the pods before sending them traffic.

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
- **CI does not inherit access.** A CodeBuild role starts with zero Kubernetes
  permissions. `access_entry.tf` gives the DeployPods role one entry with
  `AmazonEKSEditPolicy`, scoped to `eks_app_namespace` — enough to restart the app, nothing
  cluster-wide. The policy association references the entry's `principal_arn`, not the
  variable, so Terraform creates the entry first; associating a policy with an entry that
  does not exist yet is rejected.

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
- **The pipeline deploys by restart, so rollback goes through git.** DeployPods restarts the
  pods onto whatever image `eks_app_image_tag` currently points at. That tag is reused on
  every build, so `kubectl rollout undo` restores the old pod template but pulls the *new*
  image. Rollback is `git revert` and a push. Tagging each deploy with its commit SHA would
  make `rollout undo` work, but Terraform would then fight the pipeline over the tag.
- **No readiness probe on the Deployment.** A pod counts as ready the moment the container
  starts. The ALB's own health check (HTTP `GET /`) keeps traffic off a pod until Django
  answers, but Kubernetes does not wait for it, so a rollout can retire old pods before the
  new ones pass and serve a few `502`/`503`s. The controller's pod readiness gate (label the
  namespace `elbv2.k8s.aws/pod-readiness-gate-inject=enabled`) is the fix.
- **HTTP only.** The ALB has no HTTPS listener — that needs a domain and an ACM certificate.
  Its security group, created by the controller, is open to `0.0.0.0/0` on port 80, the same
  exposure the Classic Load Balancer had.
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
- **Terraform will not adopt an object `kubectl` already created.** A ServiceAccount,
  Deployment, or Service of the same name in the same namespace makes the apply fail with
  `already exists`; Terraform has no state for it and will not take it over. Delete it
  first (`kubectl delete deployment appointments-deployment`) or `terraform import` it.
  This is why all three manifests in `appointments-app/manifests/` stay commented out.
- **A missing ServiceAccount stalls the rollout for ten minutes, then fails.** `0 out of 2
  new replicas have been updated` is `wait_for_rollout` giving up; the real error is only
  in `kubectl get events` — `forbidden: error looking up service account`. Now that
  `kubernetes_service_account_v1` is in the module this should not recur, but the same
  ten-minute silence hides any other admission rejection.
- **A stale kubeconfig looks like a dead cluster.** After a rebuild, `kubectl` reports
  `no such host` against the previous endpoint. That is the local config, not the cluster
  — re-run the `eks_kubeconfig_command` output.
- **The Service's `selector` is a plain map; the Deployment's is a `selector` block with
  `match_labels`.** The same idea with two different syntaxes, and pasting one into the
  other validates as far as HCL and fails in the provider.
- **A failed Helm install is left in the cluster but not in state.** If the controller's
  rollout fails, Terraform records nothing, yet the release still exists, and the next
  apply fails with `cannot re-use a name that is still in use`. Clear it with
  `helm uninstall aws-load-balancer-controller -n kube-system`, then apply again.
- **The helm provider v3 uses attribute syntax, not blocks.** `set = [{ name, value }]` and
  `kubernetes = { exec = { … } }`, with `=` signs — unlike the block style of the
  neighbouring `kubernetes` provider. Most examples online are v2 and fail `validate`.