# Project 04 — Zero-Trust AWS Network

This project builds a **zero-trust–ready network foundation on AWS** using Terraform.

The focus is on **network design first**: clear boundaries, no implicit trust, no public access to workloads, and a structure that can safely grow without rework later.

The infrastructure is built in **small, verifiable phases**, similar to how production AWS environments are usually rolled out.

---

## What this project is about

The goal is to design a network that:

- Uses a **hub-and-spoke VPC model**
- Centralizes egress and inspection
- Prevents direct internet access from workloads
- Avoids ad-hoc or manual configuration
- Is fully reproducible using Terraform

This is not a demo or lab-style setup. It’s intentionally structured to reflect how a real environment would be designed, reviewed, and expanded over time.

---

## Tooling & prerequisites

- Terraform **1.6+**
- AWS CLI v2
- VS Code (or any editor)
- An AWS account with a **dedicated IAM user**
- Local AWS CLI profile:
  - Profile name: `zero-trust`
  - Region: `eu-west-1`

### Verify access

~~~
aws --profile zero-trust sts get-caller-identity
aws --profile zero-trust configure get region
~~~

---

## AWS authentication

Terraform uses a single, explicit AWS CLI profile (zero-trust).

This is deliberate:
- avoids accidentally running Terraform against the wrong account
- avoids shared or long-lived admin profiles
- keeps local credentials predictable

Terraform is pinned to this profile in: environments/dev/providers.tf
No environment variables are required.

---

## Repository layout

~~~
aws-zero-trust-network/
├── environments/
│   └── dev/                # Environment-level wiring
├── modules/
│   ├── vpc/                # VPC with tiered subnets
│   ├── tgw/                # Transit Gateway (later phase)
│   ├── network_firewall/   # Central inspection (later phase)
│   ├── vpc_endpoints/      # PrivateLink endpoints (later phase)
│   └── ec2_ssm/            # SSM-only compute (later phase)
├── providers.tf
├── versions.tf
├── locals.tf
└── README.md
~~~

The structure is intentionally modular so that:
environments stay thin
networking logic is reusable
changes are easy to review

---

## Terraform bootstrap

Before creating any real network resources, the Terraform setup and AWS access were validated using a minimal bootstrap apply.

~~~
cd environments/dev
terraform init
terraform plan
terraform apply
~~~

This confirmed:
- provider configuration is correct
- the zero-trust profile works as expected
- state and environment separation are clean

---

## Current state — VPC foundation

At this stage, the **network foundation and core connectivity** are deployed.

### Hub VPC

- Acts as the future inspection and egress hub
- Includes subnet tiers for:
  - Public (NAT Gateway only)
  - Private
  - Transit Gateway attachment
  - Network Firewall (reserved)
- Has an Internet Gateway
- Has a NAT Gateway
- No workloads are deployed here

### Spoke VPCs (2)

- Fully private VPCs intended for workloads
- No Internet Gateway
- No NAT Gateway
- Subnet tiers:
  - Private
  - Transit Gateway attachment
- No direct internet access

---

### Update — Transit Gateway added

A Transit Gateway has been introduced to connect the hub and spoke VPCs.

- Hub and spoke VPCs are attached to a single TGW
- Spoke default routes now point to the TGW
- Traffic is routed centrally, but no inspection or egress control is enforced yet

This phase establishes controlled connectivity without changing the security
posture of the environment.

---

### General notes

- All CIDRs and subnets are deterministic
- All resources are Terraform-managed
- Spokes do not have direct internet access
- Security enforcement is not enabled yet

This staging is intentional. The goal is to validate topology and routing
before inserting inspection and policy enforcement.

---

## What is intentionally not deployed yet

The following will be added in later phases:

- Centralized inspection with AWS Network Firewall
- Inter-VPC traffic inspection
- VPC endpoints (SSM, EC2 messages, logs, S3)
- EC2 instances
- SSM-only access model
- Zero-trust policy enforcement

Each of these will be introduced separately to keep changes easy to reason about
and easy to validate.

---

## Validation checks

After applying the current phase, the following should be true:

- Hub VPC has an IGW and NAT Gateway
- Spoke VPCs have no IGW
- Spoke route tables forward traffic to the TGW
- No public subnets exist in spoke VPCs
- All resources are tagged and traceable to Terraform

---

## Visual verification

Console screenshots are included to verify that the deployed infrastructure
matches the described architecture.

- Hub-and-spoke VPC layout
- Subnet tier separation
- Absence of internet access in spoke VPCs
- TGW attachments and routing

See:
- `docs/screenshots/phase-3-vpc-foundation/`
- `docs/screenshots/phase-4-tgw/`

---

## Next steps

The next phase introduces **centralized inspection**:

- AWS Network Firewall deployment
- Traffic steering from TGW into firewall endpoints
- Controlled egress via NAT Gateway

After that, PrivateLink endpoints and SSM-only workloads will be added.

---

## Notes from an engineering perspective

- Zero-trust starts with network boundaries
- Routing should exist before inspection, not the other way around
- Small Terraform applies are easier to review and safer to operate
- Explicit non-goals reduce confusion later
