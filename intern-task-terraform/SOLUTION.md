# Terraform and CI solution

This configuration describes one Ubuntu EC2 instance that builds and runs the app from Task 1. It supports the challenge's planning checks with fake credentials. No AWS resources were deployed.

## Network and access

The VPC uses `10.0.0.0/16`, with a subnet at `10.0.1.0/24`. The subnet has a route table with a default IPv4 route through an attached internet gateway. Public IP assignment is enabled, and the instance explicitly requests a public address.

The instance depends on the route-table association so the internet route is configured before first-boot downloads begin.

The security group allows exactly two kinds of incoming connection:

- TCP 22 from the required `ssh_cidr` input.
- TCP 5000 from any IPv4 address.

Outbound IPv4 traffic is allowed for package installation and image downloads. `ssh_cidr` has no default and rejects malformed IPv4 CIDRs and `/0` networks. The outputs are the instance's public IP and the app port, 5000.

UFW denies incoming connections by default and allows only TCP 5000. This follows the README's app-port-only host-firewall requirement. It also means SSH is blocked on the host, even from the CIDR allowed by the security group. A deployment requiring SSH administration would need an explicit host-firewall exception and SSH authentication setup.

## First-boot setup

`user_data.sh.tftpl` is rendered by Terraform and supplied as EC2 user data. It creates `appadmin` with passwordless sudo, installs Docker, certificates, sudo and UFW, and enables Docker.

Terraform reads the Task 1 Dockerfile and Python source with `filebase64`. The script decodes them into `/opt/intern-task-app` and builds `intern-task-app:local` from that directory. This uses the exact files in the submitted branch rather than fetching a branch that might change during boot. Base64 preserves the file contents; it isn't encryption.

The `intern-task-app.service` systemd unit starts after Docker and requests the network-online target. It removes a leftover app container before startup, runs `docker run` in the foreground, and restarts the service if that process exits. It is enabled for normal boot.

The container uses host networking, so the Python app listens directly on host port 5000. No Docker port publishing is used. This lets UFW's host-input rules apply to incoming app connections without the separate forwarding path created by bridge port publishing. The container still uses the non-root user defined in Task 1; `appadmin` is a separate host account.

## User-data changes

The instance explicitly sets `user_data_replace_on_change = false`. AWS provider 6.70.0 already uses this default; the setting documents the choice rather than changing the default. In this provider version, updating user data normally stops/starts the existing instance instead of replacing it.

The template uses file contents and fixed configuration, not timestamps or other changing values. An unrelated tag edit therefore doesn't change the rendered script.

Changing stored user data doesn't normally rerun cloud-init's first-boot commands. Existing servers therefore need a deliberate update or replacement process to receive setup changes. This configuration doesn't provide ongoing configuration management.

## Inputs

| Input | Default | Notes |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `ami_id` | `ami-0e2c8caa4b6378d8c` | Plausible Ubuntu AMI for planning; availability isn't verified |
| `instance_type` | `t3.micro` | x86 instance size |
| `ssh_cidr` | Required | Explicit IPv4 network narrower than `/0` |

For an actual deployment, verify that the AMI is Ubuntu, available in the chosen region and compatible with the instance architecture. The startup script assumes Ubuntu. No AWS data sources are used to look up an AMI because those would require live AWS access.

## Run the planning checks

Use a dedicated terminal and run from the repository root:

```bash
cd intern-task-terraform/terraform
export AWS_ACCESS_KEY_ID=fake
export AWS_SECRET_ACCESS_KEY=fake
export AWS_DEFAULT_REGION=us-east-1
export AWS_EC2_METADATA_DISABLED=true
export AWS_SHARED_CREDENTIALS_FILE=/dev/null
export AWS_CONFIG_FILE=/dev/null
unset AWS_PROFILE AWS_SESSION_TOKEN
export TF_VAR_ssh_cidr=203.0.113.10/32
export TF_INPUT=false

terraform fmt -check -recursive
terraform init -input=false
terraform validate
terraform plan
```

With no existing state, expect seven resources to add, zero to change, zero to destroy. `app_port` is 5000; `public_ip` is known after apply. These instructions stop at planning.

The provider includes the three skip options requested by the challenge. They skip initial checks, not every possible AWS API call; the configuration avoids live lookups and these commands use fake credentials.

`203.0.113.10/32` is an address from the RFC 5737 documentation range. It supplies a fixed, narrow example for CI, not an actual administrator address. A real deployment must supply an authorized source network. The module keeps that input required.

Commit `.terraform.lock.hcl` to keep the selected provider version and checksums. The local `.gitignore` excludes downloaded providers, state files and saved `.tfplan` files.

## CI repairs

These changes are separate from the infrastructure configuration:

- Set `defaults.run.working-directory` to the Terraform directory. Previously the commands ran at the repository root.
- Added `terraform init -input=false` before validation. A fresh runner needs the provider installed.
- Supplied `TF_VAR_ssh_cidr` and disabled interactive input so planning doesn't wait for a missing value.
- Included the workflow itself and the embedded Task 1 files in the path filters, in addition to the Terraform directory.

The workflow retains Terraform 1.12.0, fake AWS credentials and manual execution. Terraform's version requirement permits both that CI version and the locally tested 1.16.0.

## Verification and limits

The following local checks passed:

- Formatting, validation and the seven-resource plan; planned ingress and outputs were checked.
- Missing, malformed, IPv6 and world-open SSH inputs were rejected.
- An offline existing-state regression using the real provider and simulated state: unchanged configuration gave a no-op; changing only the instance name tag gave an in-place update without replacement and left user data unchanged. This wasn't state from a deployed EC2 instance.
- Rendered Bash syntax, systemd unit validation, a user-data size below 16 KiB, and byte-for-byte identity of the embedded Task 1 files.
- Fresh-directory initialization, validation and planning using Terraform 1.12.0 and locked AWS provider 6.70.0, matching CI's selected Terraform version.
- Both workflows passed actionlint. Its ShellCheck integration was disabled; Bash syntax was checked separately.

The actual rendered startup script was also executed in a disposable Ubuntu 24.04 environment running systemd and nested Docker. Passwordless host sudo, container UID 10001, active UFW, app access on port 5000, blocked peer access to a confirmed listener on port 5001, and automatic recovery after killing the app container all passed. The app and firewall came back after restarting the sandbox without rerunning setup.

Nested overlay storage wasn't supported in the sandbox, so its Docker daemon used `vfs`. This was a test-environment adjustment; the submitted startup script wasn't changed. HTTP checks waited for the app to respond after service startup.

This verifies local runtime behavior, not a real EC2/kernel reboot or cloud-init integration. No AWS resources were created. GitHub-hosted Actions hasn't run yet; the local equivalent checks passed.
