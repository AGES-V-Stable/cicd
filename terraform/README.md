# AWS deployments

This directory contains two independent deployments in `us-east-2`:

| Terraform root | Resource prefix | Default VPC CIDR | Frontend release |
| --- | --- | --- | --- |
| `environments/staging` | `vstable-staging` | `10.42.0.0/16` | Merge to frontend `main` |
| `environments/production` | `vstable-production` | `10.43.0.0/16` | Publish a stable frontend GitHub Release |

Each root has its own local Terraform state and creates a VPC, private PostgreSQL
database, ECR repository, Lambda HTTP API, private S3 bucket, CloudFront
distribution, and frontend deployment IAM role. Lambda connects directly to the
private RDS endpoint as the RDS-managed master user (`vstable_admin`). The master
user has `rds_superuser` privileges, so this choice gives the application broad
database access. Keep each state file on a secure,
persistent runner. Do not run the old root-level Terraform commands; the root is
now a module and test directory. Both databases retain the existing Single-AZ,
no-backup, no-final-snapshot policy and deletion protection.

## Account bootstrap

Apply `global/` once per AWS account before either environment. It creates the
GitHub Actions OIDC provider used by both deployment roles:

```bash
terraform -chdir=terraform/global init
terraform -chdir=terraform/global apply
```

If the account already has `token.actions.githubusercontent.com` as an IAM OIDC
provider, import its ARN into `global` instead of creating a duplicate. Preserve
the `global` state alongside the environment states.

## Provision an environment

Use Terraform 1.11+, Docker Buildx, and AWS CLI. Terraform reaches RDS only
through AWS APIs; the runner no longer needs a PostgreSQL connection to the
private database. A separate admin client still needs a private route to the
RDS subnet and the `runner_cidr` security group allowance.
Create `terraform.tfvars` from the chosen root's `terraform.tfvars.example` and
set its runner CIDR. The example's all-zero image digest is only valid for the
first targeted apply. Supply `TF_VAR_jwt_secret` (64+ characters) and optional
`TF_VAR_provider_secrets` from protected environment settings, separately for
each environment. Do not put credentials in `.tfvars` or logs.

For staging, run the following commands from the repository root. Replace the
path with `terraform/environments/production` for production, and use an image
tag unique to that environment's immutable ECR repository. The backend source
and its Lambda-compatible `Dockerfile.lambda` must be available in a separate
checkout; this infrastructure repository contains neither. A normal web-server
image is not sufficient for an AWS Lambda image deployment.

```bash
terraform -chdir=terraform/environments/staging init
terraform -chdir=terraform/environments/staging apply \
  -target=module.network -target=module.database -target=module.registry \
  -target=module.frontend -target=module.frontend_deploy_role

ECR_REPOSITORY=$(terraform -chdir=terraform/environments/staging output -raw ecr_repository_url)
ECR_REGISTRY=${ECR_REPOSITORY%%/*}
ECR_NAME=${ECR_REPOSITORY#*/}
IMAGE_TAG=deploy-001
aws ecr get-login-password --region us-east-2 |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker buildx build --platform linux/amd64 --provenance=false \
  -f Dockerfile.lambda -t "$ECR_REPOSITORY:$IMAGE_TAG" --push .
IMAGE_DIGEST=$(aws ecr describe-images --region us-east-2 \
  --repository-name "$ECR_NAME" --image-ids "imageTag=$IMAGE_TAG" \
  --query 'imageDetails[0].imageDigest' --output text)
# Set image_digest to IMAGE_DIGEST in this environment's terraform.tfvars.
terraform -chdir=terraform/environments/staging apply
```

The RDS-managed master password is read ephemerally from Secrets Manager during
the full apply and copied into the Lambda app-config secret as `DB_PASSWORD`.
The Lambda uses `DB_HOST` set to the direct RDS endpoint and reads that secret
using its IAM role. The private subnets have NAT access for Secrets Manager;
the RDS security group permits the Lambda security group on port 5432. The
application image must read `APP_CONFIG_SECRET_ARN` and use `DB_USERNAME` and
`DB_PASSWORD` from the secret. A later backend release uses a new digest in the
selected environment's `.tfvars` and a full apply. After rotating the RDS
master password, increment `app_config_version` and apply again to refresh the
Lambda app-config secret. Increment it for any other app secret change as well.
The migration adds one to the configured version to force the existing app
secret to receive the master credentials on the first apply.

If migrating an environment that already has the former application database
role, the `removed` block forgets that role without dropping it. The obsolete
RDS Proxy and its secret are removed by the plan. Review those changes before
applying. Existing local `.tfvars` files should remove the obsolete
`rds_ca_bundle_path`, `app_db_username`, `app_db_password`, and
`app_password_version` entries; keep the current state file.

## Frontend GitHub Actions

The React frontend lives in [AGES-V-Stable/frontend](https://github.com/AGES-V-Stable/frontend).
Its `.github/workflows/deploy.yml` handles the frontend release. Create GitHub environments
named `staging` and `production`. Set these nonsecret environment variables
from the matching Terraform root outputs:

| GitHub environment variable | Terraform output |
| --- | --- |
| `AWS_ROLE_ARN` | `frontend_deploy_role_arn` |
| `FRONTEND_BUCKET` | `frontend_bucket_name` |
| `FRONTEND_DISTRIBUTION_ID` | `frontend_distribution_id` |
| `VITE_API_URL` | `api_url` |

The workflow checks the frontend, builds it with that environment's API origin,
uploads Vite's hashed assets first, uploads `index.html` with revalidation, and
invalidates CloudFront. It retains older assets for browser sessions using a
previous build. A merge to `main` deploys staging; publishing a stable GitHub
Release deploys production only if its commit belongs to `main`.

The default `github_oidc_subject` uses GitHub's immutable-ID subject format for
`AGES-V-Stable/frontend` (owner ID `311973495`, repository ID `1329059304`).
The staging subject ends with `:environment:staging`; the production subject
ends with `:environment:production`. If GitHub's OIDC subject configuration
changes, set this variable to the exact subject in that environment's `.tfvars`
and apply the IAM role again. The role also restricts staging to
`refs/heads/main` and production to tag refs.

The CloudFront URL comes from `frontend_url`; no domain or TLS certificate setup
is needed. Spring CORS accepts only the corresponding CloudFront origin. Verify
deep links, login, rejected unauthenticated requests, and receipt downloads in
both deployments.

## Backend GitHub Actions

The backend workflow in `AGES-V-Stable/backend` uses OIDC to push an image to ECR
and update the Lambda. Configure its GitHub environment variables from the
matching Terraform outputs:

| GitHub environment variable | Terraform output or value |
| --- | --- |
| `AWS_ROLE_ARN` | `backend_deploy_role_arn` |
| `ECR_REPOSITORY` | `ecr_repository_url` |
| `BACKEND_LAMBDA_FUNCTION_NAME` | `vstable-staging-backend` or `vstable-production-backend` |
| `API_URL` | `api_url` |

`app_secret_arn` is a Secrets Manager ARN used by the Lambda at runtime. It is
not an IAM role ARN and must not be assigned to `AWS_ROLE_ARN`. The backend role
trusts the immutable-ID OIDC subject of `AGES-V-Stable/backend` (owner ID
`311973495`, repository ID `1332068074`), with `main` for staging and release
tags for production. If GitHub's subject configuration changes, override
`backend_github_oidc_subject` with the exact subject before applying the role.

The workflow also updates and invokes `SEED_LAMBDA_FUNCTION_NAME`. This
Terraform configuration currently creates only the public backend Lambda. A
separate private seed Lambda must be provisioned, its ARN added to
`lambda_function_arns` in the matching `backend_deploy_role` module call, and
its function name assigned to `SEED_LAMBDA_FUNCTION_NAME` before the seed step
can succeed. Do not point that variable at the public backend Lambda.
