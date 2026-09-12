# `eks` module

A Kubernetes cluster and one managed node group, plus the two IAM roles neither can start
without. Nothing is deployed to it yet — the pipeline still stops at ECR.

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
  apply fails on an undefined reference. Nothing references it today because `outputs.tf`
  is still empty — that changes the moment outputs are added.

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

Eight objects on a first apply — the three node policy attachments come from one
`for_each`.

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

All 9 are supplied by the env layer; validation lives here, not there.

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

`eks_subnets_ids` is computed from a data source in the env layer and so never passes
through `envs/dev/variables.tf` or `terraform.tfvars` — the same shape as
`appointments_db_vpc_id` on the `rds` module.

With no autoscaler installed, `min`/`max` are guardrails only: `desired` never changes on
its own.

## Outputs

None yet. Cluster name and endpoint are the obvious two — see the `count` note above for
the `try()` they will need in the env layer.

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
- **Pods cannot reach RDS.** `modules/rds` opens its security group to a single resolved
  IP. A deploy stage will need an ingress rule from the node security group.
- **No OIDC provider, no IRSA, no deploy stage, no Kubernetes manifests.** Out of scope
  while nothing runs on the cluster.
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