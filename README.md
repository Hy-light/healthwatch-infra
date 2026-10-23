# HealthWatch Naija · Infrastructure

> **Fictional company. Real pipeline.** Built for the MIVA Open University *MIT 8329 DevOps & Continuous Integration* Executive-in-Residence live lesson.

HealthWatch Naija runs a community health reporting network for clinics across Nigerian states. This repository is its **infrastructure as code**. Every change to production starts as an **Infrastructure Change Request (ICR)** and goes to Azure through code review, automated security gates and a human approval. Nobody clicks around in the portal.

```
 ICR (GitHub Issue)  ──►  Pull Request (edit terraform.tfvars)
                               │
                               ▼
              ┌───────── ICR Review: Plan & Policy ─────────┐
              │ 1 format/validate  2 terraform plan          │
              │ 3a policy rule (jq)  3b Checkov security scan│
              │ → results posted on the PR for reviewers     │
              └──────────────────────────────────────────────┘
                               │ merge
                               ▼
              ┌──────── ICR Implement: Apply to Azure ───────┐
              │ final plan → ⏸ CAB approval → terraform apply│
              └──────────────────────────────────────────────┘
                               │
                               ▼
     Azure (South Africa North): RG · VNet/NSG · Storage + status page
                                 · Log Analytics · Budget alert
                               │
              Drift Detection (daily) ── opens an issue if Azure ≠ code
```

## What's in here

| Path | Purpose |
|---|---|
| `terraform/` | The environment. **`terraform.tfvars` is the only file an ICR changes.** |
| `.github/ISSUE_TEMPLATE/icr.yml` | The ICR form |
| `.github/workflows/terraform-plan.yml` | PR review: validate, plan, policy, Checkov, comment |
| `.github/workflows/terraform-apply.yml` | Merge → plan → approval gate → apply |
| `.github/workflows/drift-detection.yml` | Finds "ClickOps" changes made outside the pipeline |
| `.github/workflows/terraform-destroy.yml` | Decommission (type DESTROY + approval) |
| `scripts/bootstrap-azure.sh` | One-time Azure setup (state storage + OIDC identity) |
| `docs/demo-kit/` | Copy-paste material for the live lesson |

**Cost:** under $2/month while running (storage, a tiny VNet and Log Analytics with almost no data).

---

## One-time setup (≈45 minutes)

### 1. Put the code on GitHub
Create a **public** repository called `healthwatch-infra` (public = free approval gates, and students can fork it).

Easiest route: open **Azure Cloud Shell** (shell.azure.com, Bash), upload the zip with the *Upload* button, then:
```bash
unzip healthwatch-infra.zip && cd healthwatch-infra
git init -b main && git add . && git commit -m "Baseline: ICR-0041 Lagos pilot"
git remote add origin https://github.com/<YOUR-USER>/healthwatch-infra.git
gh auth login            # choose GitHub.com > HTTPS > login with browser
git push -u origin main
```
(GitHub Desktop works too. Just make sure the hidden `.github` folder is uploaded.)

The push will trigger the apply workflow, which **fails because Azure isn't connected yet. That's expected.**

### 2. Connect Azure (OIDC, no passwords)
In the same Cloud Shell:
```bash
GITHUB_REPO="<YOUR-USER>/healthwatch-infra" bash scripts/bootstrap-azure.sh
```
It prints 5 values. In GitHub go to **Settings → Secrets and variables → Actions → Variables tab** and add each one as a *repository variable*:
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`.

### 3. Create the approval gate (the "CAB")
**Settings → Environments → New environment → `production`**
- Tick **Required reviewers** and add yourself
- Leave **Prevent self-review** unticked (you are approving your own demo)
- Save

### 4. Protect `main`
**Settings → Branches → Add branch protection rule** (or Rulesets) for `main`:
- Require a pull request before merging (0 approvals is fine for the demo)
- Require status checks to pass, and search for and add **`Plan & Policy`** (it shows up after the first PR has run)

### 5. Set your email
Edit `terraform/terraform.tfvars` and set `owner_email` to a mailbox you can see (budget alerts go there). Commit straight to `main` (or via PR once protection is on).

### 6. First deployment
**Actions → ICR Implement: Apply to Azure → Run workflow.** When it pauses, click **Review deployments → production → Approve**.
The run summary shows the **status page URL**. Open it on your phone. You should see Lagos only, with ICR-0041.

### 7. Prove there is no drift
**Actions → Drift Detection → Run workflow.** It must report **No drift**. If it reports drift on a fresh environment, tell me what it shows and we'll pin it.

### 8. Full rehearsal, then reset
Follow the run sheet end to end (ICR → PR with `docs/demo-kit/2-...` → see it blocked → fix with `3-...` → merge → approve → drift demo).
Then **reset for Saturday**: put back the baseline `terraform.tfvars` (Lagos only, ICR-0041, `vendor_ssh_sources = []`) through a PR, merge, approve, and close the rehearsal issues.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `AADSTS700213` / "No matching federated identity record" | Repo name in `GITHUB_REPO` must match exactly (case-sensitive). Re-run bootstrap with the right name. |
| `AuthorizationFailed` right after bootstrap | Role assignments take 1–5 minutes. Re-run the job. |
| Budget error about `start_date` | Budgets must start on the 1st of the *current* month. It is computed automatically; re-run if you crossed midnight on the 1st. |
| Storage account name already taken | Very unlikely (the name has a random suffix). Re-run the workflow. |
| Plan comment not posted | Settings → Actions → General → Workflow permissions → "Read and write permissions". |
| State lock error | Another run is in progress. Wait, or re-run after it finishes. |

Built by Prince Ugochukwu Chime · [linkedin.com/in/puchime](https://linkedin.com/in/puchime)
