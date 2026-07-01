# Infra: serving the on-device model across regions

`setup_frontdoor.sh` provisions **Azure Front Door (Standard)** in front of a
Blob Storage container so the multi-GB Gemma model downloads fast from the
nearest region to every user, behind one **tokenless** HTTPS URL.

## Prerequisites
- [`azure-cli`](https://aka.ms/azure-cli) (`az`) and `curl`.
- An Azure subscription. The script runs `az login` for you if needed.

## Run
```bash
./tool/infra/setup_frontdoor.sh
```
It is **idempotent** — safe to re-run. On completion it prints the tokenless CDN
URL and the exact build flag:
```
--dart-define=GEMMA_MODEL_CDN_URL=https://<endpoint>.z01.azurefd.net/models/<file>
```
A CDN URL is always fetched with **no** SAS/token (see `lib/main.dart`
`_gemmaService` → `selectModelNetworkSource`); the edge handles origin auth.

## Config
Set via environment variables or an untracked `tool/infra/.env.infra` file
(git-ignored). Everything has a default — see the header of
`setup_frontdoor.sh`. Common ones:

| Var | Default | Notes |
|-----|---------|-------|
| `AZURE_SUBSCRIPTION` | current | Subscription id/name |
| `RESOURCE_GROUP` | `stepwise-model-rg` | |
| `LOCATION` | `eastus` | RG/storage region (Front Door is global) |
| `STORAGE_ACCOUNT` | `stepwisemodel<rand>` | 3–24 lowercase alnum, globally unique |
| `MODEL_FILE` | `model/gemma-3n-E2B-it-int4.litertlm` | local file to upload |
| `PUBLIC_CONTAINER` | `true` | anon blob read (weights aren't secret) |
| `SKIP_UPLOAD` | `false` | skip the large upload if already uploaded |

## Private origin
With `PUBLIC_CONTAINER=false` the container stays private and Front Door will
`403` until you grant origin access — e.g. a Front Door **Rules Engine** rule
that appends a SAS toward the origin, or a **Private Link** origin. Keep the
*public* URL tokenless either way.

## Propagation & troubleshooting
Front Door edge config is **global** and not instant. The first deploy of a new
endpoint takes **up to ~20 min**; **back-to-back** config changes can take
**up to ~40 min** ([AFD FAQ](https://learn.microsoft.com/azure/frontdoor/front-door-faq)).
Until it's live, requests return `404` with `X-Cache=CONFIG_NOCACHE` — that is
"edge config not applied yet", not a routing bug.

- **Don't** repeatedly toggle/recreate resources to "force" it — each change
  restarts the rollout clock. Make one change, then wait.
- Verify with `curl -I <cdn-url>`; expect `HTTP 200`. A `TCP_HIT` on the second
  request from the same region confirms caching.
- If it's still 404 after ~30 min, confirm the origin itself works:
  `curl -I https://<account>.blob.core.windows.net/models/<file>` (should be 200)
  and that `Microsoft.Cdn` is `Registered`
  (`az provider show -n Microsoft.Cdn --query registrationState`). The script now
  registers it up front to avoid a stuck first deployment.

## Cost note
Front Door Standard has a small base + egress cost. Weights are versioned by
filename and served with `Cache-Control: public, max-age=31536000, immutable`,
so edges cache aggressively and origin egress stays minimal.
