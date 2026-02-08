# Project 04 — Zero-Trust AWS Network

This project builds a **zero-trust–ready network foundation on AWS** using Terraform.

The focus is on **network design first**: clear boundaries, no implicit trust, no public access to workloads, and a structure that can safely grow without rework later.

The infrastructure is built in **small, verifiable phases**, closely reflecting how production AWS environments are typically designed, reviewed, and rolled out.

---

## What this project is about

The goal is to design a network that:

- Uses a **hub-and-spoke VPC model**
- Centralizes egress and inspection
- Prevents direct internet access from workloads
- Avoids ad-hoc or manual configuration
- Is fully reproducible using Terraform

This is not a demo or throwaway lab. It is intentionally structured to mirror real-world cloud network architecture and operational decision-making.

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

Terraform uses a single, explicit AWS CLI profile (`zero-trust`).

This is deliberate:
- avoids accidentally running Terraform against the wrong account
- avoids shared or long-lived admin profiles
- keeps local credentials predictable and auditable

Terraform is pinned to this profile in `environments/dev/providers.tf`.  
No environment variables are required.

---

## Repository layout

~~~
aws-zero-trust-network/
├── environments/
│   └── dev/                     # Environment-level wiring
│
├── modules/
│   ├── vpc/                     # VPC with tiered subnets
│   ├── tgw/                     # Transit Gateway and routing
│   ├── network_firewall/        # Central inspection and firewall policies
│   ├── vpc_endpoints/           # PrivateLink endpoints
│   └── ec2_ssm/                 # SSM-only compute
│
├── docs/
│   └── screenshots/
│       ├── phase-3-vpc-foundation/
│       ├── phase-4-tgw/
│       ├── phase-5-firewall/
│       ├── phase-6-zero-trust/
│       ├── phase-7-privatelink-ssm/
│       ├── phase-8-observability/
│       └── phase-9-proof-tests/
│
├── providers.tf
├── versions.tf
├── locals.tf
└── README.md
~~~

The structure is intentionally modular so that:
- environments stay thin
- networking logic is reusable
- changes are easy to review and reason about

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

## Current state — Network foundation and enforcement

At this stage, the **network foundation, routing, inspection, and access controls** are fully deployed and validated.

### Hub VPC

- Acts as the centralized inspection and egress hub
- Subnet tiers:
  - Public (NAT Gateway only)
  - Private
  - Transit Gateway attachment
  - Network Firewall
- Has an Internet Gateway and NAT Gateway
- No workloads are deployed in the hub

### Spoke VPCs (2)

- Fully private VPCs intended for workloads
- No Internet Gateway
- No NAT Gateway
- Subnet tiers:
  - Private
  - Transit Gateway attachment
- No direct internet access

---

### Update — Transit Gateway

A Transit Gateway connects the hub and spoke VPCs.

- Hub and spokes are attached to a single TGW
- Spoke default routes point to the TGW
- TGW routing is explicitly controlled via a dedicated route table

See: `docs/screenshots/phase-4-tgw/`

---

### Update — Network Firewall (in-path)

Network Firewall is deployed in the hub and inserted directly into the traffic path.

- Traffic arriving from the TGW is steered into the firewall
- Internet-bound traffic exits via NAT **after inspection**
- Return routes from firewall subnets back to spokes are in place

See: `docs/screenshots/phase-5-firewall/`

---

### Update — Zero-trust firewall baseline

Firewall rules enforce a strict zero-trust posture.

- Explicit allow:
  - DNS (53)
  - HTTPS (443)
  - NTP (123)
- Default deny for all other traffic
- No implicit or broad internet access

See: `docs/screenshots/phase-6-zero-trust/`

---

### Update — PrivateLink + SSM-only access (no inbound)

Workload access is enabled without inbound connectivity.

- Interface endpoints are deployed in workload VPCs for Private DNS resolution
- Hub remains responsible for inspection and controlled egress
- A private EC2 instance runs with:
  - no public IP
  - no inbound rules
- Access is validated using **SSM Session Manager only**

See: `docs/screenshots/phase-7-privatelink-ssm/`

---

### Update — Observability

Network Firewall logs are sent to CloudWatch Logs.

- Flow and alert logs are enabled
- Log streams are created dynamically as traffic flows
- Short retention is used for cost awareness

See: `docs/screenshots/phase-8-observability/`

---

### Update — Proof tests and inspection validation

Traffic from a private EC2 instance was tested through the full inspection path.

- DNS resolution is permitted
- HTTPS egress to required AWS services is allowed
- IP-based and non-essential outbound traffic is blocked
- Network Firewall logs confirm inspected and denied flows

See: `docs/screenshots/phase-9-proof-tests/`

---

## Validation checks

After all phases, the following are true:

- Hub VPC has IGW and NAT Gateway
- Spoke VPCs have no IGW
- Spoke route tables forward traffic to the TGW
- TGW forwards `0.0.0.0/0` to the hub attachment
- Hub TGW route tables steer traffic into Network Firewall endpoints
- Firewall route tables forward:
  - `0.0.0.0/0` → NAT Gateway
  - spoke CIDRs → Transit Gateway
- No public subnets exist in spoke VPCs
- Firewall policy enforces default deny
- Only explicitly allowed traffic exits the network
- All resources are tagged and fully Terraform-managed

---

## Engineering notes

- Zero-trust starts with **network boundaries and routing**
- Inspection must be **in-path**, not optional
- Default deny is safer than incremental deny
- IP-based egress is intentionally blocked to prevent policy bypass
- Small, phased Terraform applies are easier to review and safer to operate

---

## Teardown

This environment is intentionally designed to be **destroyed cleanly** after validation.

~~~
cd environments/dev
terraform destroy
~~~

This removes all billable resources (NAT Gateway, Network Firewall, TGW) to avoid unnecessary cost.
