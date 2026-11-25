# Deploy Ghost on AWS with Session Manager

This deploys a plain Ghost blog on one Ubuntu 24.04 arm64 EC2 instance. Caddy serves HTTPS, Ghost stores content on disk, and MySQL 8 stores the database on an encrypted GP3 volume. The default region is `us-east-1`. Budget about $30–31 per month for the instance, disk, public IPv4 address, and basic DNS, before domain registration, tax, or variable usage.

## Prerequisites

- Terraform 1.11 or later, Bash, AWS CLI v2, the Session Manager plugin, `curl` 7.71 or later, `jq`, and standard `tar` and `base64` utilities. Local validation also needs Docker Compose and ShellCheck.
- A locally configured AWS CLI profile with short-lived credentials. The deployer needs permission to manage the tagged VPC and EC2 resources, attach and pass the instance role, read the Canonical public Ubuntu AMI parameter, manage records in the specified Route 53 zone, and send and inspect `AWS-RunShellScript` commands on the blog instance. Shell operators need `ssm:StartSession` on the blog instance and permission to manage their own sessions.
- A public Route 53 hosted zone already delegated to AWS, and an unused hostname within it. The example uses placeholders. The deployment owns the blog's A record and leaves the existing zone in place.

## Deploy

From `infra/ghost/`, copy the example and replace its hostname and hosted zone ID. The live variables file stays local.

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit domain and hosted_zone_id, then run the deployment with your locally configured profile.
AWS_PROFILE=blog-deployer ./deploy.sh
```

You can also supply `TF_VAR_domain` and `TF_VAR_hosted_zone_id` in the environment. Terraform prints a plan and the script rejects changes that would delete or replace resources. It then applies the plan, waits for Systems Manager, runs the Compose setup through SSM, and checks public HTTPS. If it stops after provisioning, correct the reported issue and rerun with the same state and settings. Keep a protected copy of the local Terraform state for updates and teardown.

The script prints the blog and editor URLs plus the exact shell command. At `/ghost/`, complete Ghost's first-run owner setup promptly. Ghost Admin stays on the public site and uses Ghost's own login. A later deployment can put the editor behind an authenticated proxy or a separate private access route.

## Open a shell and check public exposure

Use the command printed by the script, or substitute the output instance ID and region in the example.

```sh
aws ssm start-session --profile blog-operator --region us-east-1 --target i-REPLACE_ME
```

From a machine outside AWS, check the deployment's public IPv4 address with `nc -vz -w 5 PUBLIC_IPV4 22`. The connection should time out or be refused. A successful connection is a deployment failure. Check public HTTPS separately with `curl --fail https://YOUR_BLOG_HOSTNAME/`.

The security group allows inbound TCP 80 and 443. Cloud-init disables the host SSH service and socket. The instance uses an outbound SSM agent and an IAM role with IMDSv2 required. Only Caddy publishes ports. MySQL lives on an internal Docker network, Caddy runs as an unprivileged user, and Ghost and MySQL use their official entrypoints to drop privileges. Database credentials are generated on the host in a root-only file. Routine host security patches are automatic. Reboot windows and application image upgrades are scheduled manually.

## Updates, backups, and teardown

Before an application update, make a backup from the SSM shell with `sudo /opt/ghost/backup.sh`. Review and update the pinned image versions in `compose.yml`, then rerun `./deploy.sh` with the same variables and state. Check the public site and editor afterward. For OS updates that require a reboot, use a maintenance window and reconnect through SSM.

The daily systemd job saves a compressed MySQL dump and a content archive under `/opt/ghost/backups/`. It prunes older local copies after about a week. The database dump is consistent, while file uploads should be paused during a backup used for migration or restore. Move a copy to encrypted storage outside the VM before destructive changes. Recover by initializing a fresh stack, stopping Ghost, restoring the content archive into `/opt/ghost/content` and the SQL dump into the Compose MySQL service's `ghost` database, and starting Ghost again. Verify the restored site before sending traffic to it.

When you have an off-host backup, run `AWS_PROFILE=blog-deployer ./destroy.sh` from the same checkout and type `destroy` after reviewing the plan. The VM, disk, and blog record are removed. The public hosted zone stays in place.

## Free local verification

```sh
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform test
shellcheck -s bash deploy.sh destroy.sh configure-host.sh backup.sh user-data.sh.tftpl
./deploy.sh --dry-run
```

The dry run uses a mocked AWS provider and validates Compose with dummy values. The checks can download Terraform providers or images and use only local resources. The AWS provider version is pinned in `versions.tf`. Terraform generates the provider checksum lockfile on the first successful initialization.

## Not verified

The final files were reviewed by reading only because the previous run was interrupted. Terraform formatting, initialization and validation, ShellCheck, Compose config, mocked tests, the deploy dry run, the local Ghost smoke test, and the RBAC backend suite were not run on this revision. Terraform's provider checksum lockfile was not generated.

Live AWS provisioning, cloud-init and SSM behavior, IAM authorization, DNS delegation, HTTPS certificate issuance, an external port-22 check, backups, restore, and teardown remain unverified.
