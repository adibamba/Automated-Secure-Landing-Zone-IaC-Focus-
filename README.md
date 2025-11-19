# SALZ — Secure Automated Landing Zone (MVP)

Overview
- Policy-driven Azure landing zone with IaC (Terraform), automated CI checks, policy enforcement, and a remediation Function.

Quickstart
1. Create Azure subscription or use Azure free tier.
2. Run infra/terraform/backend-setup.sh <SUBSCRIPTION_ID> (Git Bash/WSL recommended on Windows).
3. Copy infra/terraform/terraform.tfvars.example -> infra/terraform/terraform.tfvars and fill backend names.
4. cd infra/terraform && terraform init && terraform apply -auto-approve

CI/CD
- PRs run formatting, Checkov and terraform plan.
- Merges to main run Terraform apply (via GitHub Actions).

Demo
1. Create a test resource missing diagnostics (e.g., VM).
2. Watch Policy -> Compliance for the DeployIfNotExists assignment to apply diagnostic settings.
3. Invoke remediation function with resourceId to force-enable diagnostics.

See docs/REFERENCES.md for links.
