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

A Transit Gateway connects the hub and spoke VPCs.

- Hub and spoke VPCs are attached to a single TGW
- Spoke default routes point to the TGW
- Connectivity is established, but traffic inspection is introduced separately

---

### Update — Network Firewall inserted (in-path)

Network Firewall is deployed in the hub and inserted into the routing path.

- Traffic arriving from the TGW is steered into the firewall
- Internet-bound traffic exits via NAT after inspection
- Return routes from the firewall subnets back to spokes are in place

See: `docs/screenshots/phase-5-firewall/`

### Update — Firewall rules tightened (zero-trust baseline)

Firewall rules are now locked down with a default-deny approach.

- Explicit allow: DNS (53), HTTPS (443), NTP (123)
- Default deny for everything else
- This is intentionally minimal and will be expanded only when workloads require it

---

### General notes

- All CIDRs and subnets are deterministic
- All resources are Terraform-managed
- Spokes do not have direct internet access
- Hub-and-spoke routing is established via TGW
- Security enforcement is enabled (default deny with explicit allow rules)

This staging is intentional. The goal is to validate topology, routing, and
traffic flow before introducing stricter security controls.

---

## What is intentionally not deployed yet

The following will be added in later phases:

- Additional firewall rules as workloads are introduced (tighter egress, app/domain controls if needed)
- Controlled east-west policies (spoke-to-spoke via inspection)
- VPC endpoints (SSM, EC2 messages, logs, S3) to reduce NAT dependency
- EC2 instances
- SSM-only access model (no inbound access, no public IPs)
- Workload-level zero-trust enforcement (least privilege + segmentation)

Each of these will be introduced separately to keep changes easy to reason about
and easy to validate.

---

## Validation checks

After applying the current phase, the following should be true:

- Hub VPC has an IGW and NAT Gateway
- Spoke VPCs have no IGW
- Spoke route tables forward traffic to the TGW
- Hub TGW route table forwards `0.0.0.0/0` to a Network Firewall endpoint
- Hub firewall route table includes:
  - `0.0.0.0/0` → NAT Gateway
  - spoke CIDRs → Transit Gateway
- No public subnets exist in spoke VPCs
- Firewall policy enforces a default deny posture
- Only DNS/HTTPS/NTP are allowed outbound at this stage
- All resources are tagged and traceable to Terraform

---

## Visual verification

Console screenshots are included to verify that the deployed infrastructure
matches the described architecture.

- Hub-and-spoke VPC layout
- Subnet tier separation
- Absence of internet access in spoke VPCs
- TGW attachments and routing
- Network Firewall insertion and routing

See:
- `docs/screenshots/phase-3-vpc-foundation/`
- `docs/screenshots/phase-4-tgw/`
- `docs/screenshots/phase-5-firewall/`

---

## Next steps

Next phase focuses on removing internet dependency from workloads:

- Add PrivateLink (VPC endpoints) for SSM and required AWS services
- Reduce NAT usage by keeping AWS service traffic private

After that, private EC2 workloads will be deployed and validated using
AWS Systems Manager Session Manager (SSM-only access, no inbound connectivity).

---

## Notes from an engineering perspective

- Zero-trust starts with network boundaries
- Routing should exist before inspection, not the other way around
- Small Terraform applies are easier to review and safer to operate
- Explicit non-goals reduce confusion later

