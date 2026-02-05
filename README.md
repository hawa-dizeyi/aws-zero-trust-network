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

## AWS authentication

This project uses a dedicated AWS CLI profile:

- Profile: `zero-trust`
- Region: `eu-west-1`

Verify:

~~~
aws --profile zero-trust sts get-caller-identity
~~~

Terraform is configured to use this profile explicitly in environments/dev/providers.tf.

## Bootstrap (validate Terraform wiring)

~~~
cd environments/dev
terraform init
terraform plan
terraform apply
~~~
