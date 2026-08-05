---
name: gcloud-isolated-auth
description: Set up a dedicated, isolated gcloud configuration for a specific project/user — avoiding cross-project contamination when working across multiple Qwiklabs/training projects.
source: auto-skill
extracted_at: '2026-07-13T09:14:27Z'
---

# GCloud Isolated Authentication

## Purpose

When working across multiple Google Cloud projects (especially Qwiklabs/training
environments with many `student-XX@qwiklabs.net` accounts), the default shared
`~/.config/gcloud` dir accumulates accounts across projects and the active
account can silently flip. This procedure creates a **dedicated, isolated
gcloud configuration** for a single project that keeps auth and ADC cleanly
separated.

## Procedure

### Step 1: Check existing state

```bash
gcloud config configurations list   # what configs and accounts exist?
gcloud auth list                     # which accounts are already credentialed?
```

### Step 2: Create the isolated configuration

```bash
gcloud config configurations create <name>  # e.g. qwiklabs-01
gcloud config set project <project-id>
gcloud config set account <user-email>
```

### Step 3: Authenticate

```bash
gcloud auth login <user-email>
```

This opens a browser for the OAuth flow. Qwiklabs accounts typically use
the "Sign in with Google" button.

### Step 4: Verify

```bash
gcloud config configurations describe <name>
gcloud auth list --filter=status:ACTIVE
gcloud projects describe <project-id>   # proves the account has access
```

### Step 5: Set up ADC (Application Default Credentials) for Terraform/OpenTofu

The `google` Terraform provider resolves credentials in this order:
1. `GOOGLE_OAUTH_ACCESS_TOKEN` env var (preferred — explicit, per-call)
2. `GOOGLE_APPLICATION_CREDENTIALS` / ADC file
3. Active gcloud account

**Preferred approach — per-call token export** (avoids ADC file staleness):

```bash
export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null)"
tofu init / plan / apply ...
```

**Alternative — ADC login** (persistent, but can go stale across tabs):

```bash
gcloud auth application-default login
tofu init / plan / apply ...
```

### Step 6 (GKE): Pin KUBECONFIG

```bash
export KUBECONFIG="$HOME/.kube-<name>"   # prevents parallel tab context collision
gcloud container clusters get-credentials ...
```

## Key gotchas

- **`GOOGLE_OAUTH_ACCESS_TOKEN` must be re-exported on every shell call**
  (the token expires in ~1h; long applies can hit 401s mid-deploy).
- **The ADC file is shared across configs** — a prior `gcloud auth
  application-default login` in another tab can overwrite it.
- **MacOS note**: GNU `timeout` is absent; provide a shim if wrapping tofu
  with `timeout`.
