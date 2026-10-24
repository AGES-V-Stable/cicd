# AWS deployments

This directory contains two independent deployments in `us-east-2`:

| Terraform root | Resource prefix | Default VPC CIDR | Frontend release |
| --- | --- | --- | --- |
| `environments/staging` | `vstable-staging` | `10.42.0.0/16` | Merge to frontend `main` |
| `environments/production` | `vstable-production` | `10.43.0.0/16` | Publish a stable frontend GitHub Release |

Each root has its own local Terraform state and creates a VPC, private PostgreSQL
database, ECR repository, Lambda HTTP API, private S3 bucket, CloudFront
distribution, and frontend deployment IAM role. Keep each state file on a secure,
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

Use Terraform 1.11+, Docker Buildx, AWS CLI, and a runner connected to the new
VPC's private database network. The runner must have a route to the private
subnets and a trusted [RDS CA bundle](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem).
Create `terraform.tfvars` from the chosen root's `terraform.tfvars.example` and
set its runner CIDR and CA path. The example's all-zero image digest is only
valid for the first targeted apply. Supply `TF_VAR_app_db_password` (16+
characters), `TF_VAR_jwt_secret` (64+ characters), and optional
`TF_VAR_provider_secrets` from protected environment settings, separately for
each environment. Do not put credentials in `.tfvars` or logs.

For staging, run the following commands from the repository root. Replace the
path with `terraform/environments/production` for production, and use an image
tag unique to that environment's immutable ECR repository.

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

Finish the runner's private network route before the full apply. Terraform's
PostgreSQL provider must connect directly to RDS to create the application
role. A later backend release uses a new digest in the selected environment's
`.tfvars` and a full apply. Changing the DB password requires incrementing
`app_password_version` and `app_config_version`; changing other app secrets
requires incrementing `app_config_version`.

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

The default `github_oidc_subject` assumes GitHub's repository-name subject
format (`repo:AGES-V-Stable/frontend:environment:staging` or `production`). If
the repository uses GitHub's immutable-ID subject format, set this variable to
the exact subject in that environment's `.tfvars` before applying the IAM role.
The role also restricts staging to `refs/heads/main` and production to tag refs.

The CloudFront URL comes from `frontend_url`; no domain or TLS certificate setup
is needed. Spring CORS accepts only the corresponding CloudFront origin. Verify
deep links, login, rejected unauthenticated requests, and receipt downloads in
both deployments.
