## Tooling & prerequisites

- Terraform >= 1.6
- AWS CLI v2
- VS Code (recommended)
- AWS credentials configured locally with a profile (example: `zero-trust`)
  - Region: `eu-west-1`

### Verify access

~~~
aws --profile zero-trust sts get-caller-identity
aws --profile zero-trust configure get region
~~~
