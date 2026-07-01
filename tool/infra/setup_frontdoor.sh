#!/usr/bin/env bash
#
# setup_frontdoor.sh — Provision Azure Front Door (Standard) in front of a Blob
# Storage container so the on-device Gemma model is served, edge-cached, from
# the nearest region to every user — with a single, TOKENLESS URL.
#
# WHY THIS SCRIPT EXISTS
#   The Gemma model is multi-GB and downloaded on first launch. Serving it from
#   one region is slow for far-away users, and Azure Blob SAS is per-account and
#   awkward to ship (see build-script.bash). Front Door gives every region an
#   edge-cached copy behind one global HTTPS host, and lets us serve a URL with
#   NO SAS/token in the app:
#
#     --dart-define=GEMMA_MODEL_CDN_URL=https://<endpoint>.z01.azurefd.net/models/<file>
#
#   (See lib/main.dart `_gemmaService` / selectModelNetworkSource: a CDN URL is
#   always fetched tokenless; the edge handles origin auth.)
#
# WHAT IT DOES (idempotent — safe to re-run)
#   1. Ensures you are logged in (`az login`) and a subscription is selected.
#   2. Creates: resource group, Standard v2 storage account, `models` container.
#   3. Uploads the model with an immutable, long-lived Cache-Control header.
#   4. Creates: Front Door profile, endpoint, origin group, blob origin, route
#      (/models/* over HTTPS, query-string-agnostic caching).
#   5. Optionally makes the container anonymously readable (weights aren't
#      secret) so the public URL needs no SAS at all.
#   6. Prints the tokenless CDN URL + the exact --dart-define to build with,
#      and verifies edge caching with two HEAD requests.
#
# USAGE
#   ./tool/infra/setup_frontdoor.sh
#
# CONFIG (env vars or an untracked tool/infra/.env.infra shell file; sensible
# defaults for everything):
#   AZURE_SUBSCRIPTION      Subscription id/name to target (else the default).
#   RESOURCE_GROUP          Default: stepwise-model-rg
#   LOCATION                Default: eastus            (RG/storage region)
#   STORAGE_ACCOUNT         Default: stepwisemodel<rand>  (3-24 lowercase alnum)
#   CONTAINER               Default: models
#   MODEL_FILE              Local path to upload. Default: model/gemma-3n-E2B-it-int4.litertlm
#   BLOB_NAME               Name in the container. Default: basename of MODEL_FILE
#   FRONTDOOR_PROFILE       Default: stepwise-fd
#   FRONTDOOR_ENDPOINT      Default: stepwise
#   PUBLIC_CONTAINER        "true" (default) makes the container blob-anonymous
#                           read; "false" keeps it private (you then wire origin
#                           auth via a Front Door rule / Private Link yourself).
#   SKIP_UPLOAD             "true" to skip the (large) blob upload step.
#
# REQUIREMENTS: azure-cli (`az`), curl. The `az afd` commands need a recent CLI;
# the script installs the `front-door` extension prompt-free if missing.

set -euo pipefail

# ---- pretty logging -------------------------------------------------------
log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  \xe2\x9c\x93\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# ---- 0. Load optional untracked config ------------------------------------
if [[ -f "$SCRIPT_DIR/.env.infra" ]]; then
  log "Loading config from tool/infra/.env.infra"
  set -o allexport
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env.infra"
  set +o allexport
fi

command -v az >/dev/null 2>&1 || die "azure-cli not found. Install: https://aka.ms/azure-cli"
command -v curl >/dev/null 2>&1 || die "curl not found."

# ---- config with defaults -------------------------------------------------
RESOURCE_GROUP="${RESOURCE_GROUP:-stepwise-model-rg}"
LOCATION="${LOCATION:-eastus}"
CONTAINER="${CONTAINER:-models}"
MODEL_FILE="${MODEL_FILE:-model/gemma-3n-E2B-it-int4.litertlm}"
BLOB_NAME="${BLOB_NAME:-$(basename "$MODEL_FILE")}"
FRONTDOOR_PROFILE="${FRONTDOOR_PROFILE:-stepwise-fd}"
FRONTDOOR_ENDPOINT="${FRONTDOOR_ENDPOINT:-stepwise}"
PUBLIC_CONTAINER="${PUBLIC_CONTAINER:-true}"
SKIP_UPLOAD="${SKIP_UPLOAD:-false}"
# Storage account names must be globally unique, 3-24 lowercase alphanumerics.
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-stepwisemodel$(printf '%04x' $((RANDOM % 65536)))}"

# ---- 1. Login + subscription ---------------------------------------------
log "Checking Azure login"
if ! az account show >/dev/null 2>&1; then
  warn "Not logged in — launching 'az login'"
  az login >/dev/null
fi
if [[ -n "${AZURE_SUBSCRIPTION:-}" ]]; then
  az account set --subscription "$AZURE_SUBSCRIPTION"
fi
SUB_NAME="$(az account show --query name -o tsv)"
ok "Using subscription: $SUB_NAME"

# Ensure the Front Door CLI extension is present (older CLIs lack `az afd`).
if ! az extension show --name front-door >/dev/null 2>&1; then
  log "Installing az 'front-door' extension"
  az extension add --name front-door --only-show-errors >/dev/null || true
fi

# Register the Microsoft.Cdn resource provider BEFORE creating any Front Door
# resources and wait until it is Registered. If we let the first `az afd`
# command trigger registration, the profile/endpoint/route created moments later
# never kick off their edge deployment (deploymentStatus stays 'NotStarted' and
# every request 404s with X-Cache=CONFIG_NOCACHE). Registering up front avoids
# that stuck-deployment state.
CDN_STATE="$(az provider show -n Microsoft.Cdn --query registrationState -o tsv 2>/dev/null || echo Unknown)"
if [[ "$CDN_STATE" != "Registered" ]]; then
  log "Registering resource provider 'Microsoft.Cdn' (one-time, can take a few minutes)"
  az provider register -n Microsoft.Cdn -o none
  for _ in $(seq 1 60); do
    CDN_STATE="$(az provider show -n Microsoft.Cdn --query registrationState -o tsv 2>/dev/null || echo Unknown)"
    [[ "$CDN_STATE" == "Registered" ]] && break
    sleep 10
  done
  [[ "$CDN_STATE" == "Registered" ]] \
    && ok "Microsoft.Cdn registered" \
    || warn "Microsoft.Cdn still '$CDN_STATE' — Front Door deploy may lag; re-run later if requests 404."
else
  ok "Microsoft.Cdn already registered"
fi

# ---- helpers --------------------------------------------------------------
exists() { "$@" >/dev/null 2>&1; }

# ---- 2. Resource group ----------------------------------------------------
log "Ensuring resource group '$RESOURCE_GROUP' ($LOCATION)"
if exists az group show -n "$RESOURCE_GROUP"; then
  ok "Resource group exists"
else
  az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o none
  ok "Created resource group"
fi

# ---- 3. Storage account + container ---------------------------------------
log "Ensuring storage account '$STORAGE_ACCOUNT'"
if exists az storage account show -n "$STORAGE_ACCOUNT" -g "$RESOURCE_GROUP"; then
  ok "Storage account exists"
else
  az storage account create -n "$STORAGE_ACCOUNT" -g "$RESOURCE_GROUP" \
    -l "$LOCATION" --sku Standard_LRS --kind StorageV2 \
    --allow-blob-public-access "$PUBLIC_CONTAINER" -o none
  ok "Created storage account"
fi

BLOB_HOST="${STORAGE_ACCOUNT}.blob.core.windows.net"
# Use the account key for data-plane ops so the script works without waiting for
# an RBAC role assignment to propagate.
ACCOUNT_KEY="$(az storage account keys list -n "$STORAGE_ACCOUNT" \
  -g "$RESOURCE_GROUP" --query '[0].value' -o tsv)"

PUBLIC_ACCESS_FLAG="off"
[[ "$PUBLIC_CONTAINER" == "true" ]] && PUBLIC_ACCESS_FLAG="blob"

log "Ensuring container '$CONTAINER' (public-access=$PUBLIC_ACCESS_FLAG)"
if exists az storage container show --name "$CONTAINER" \
    --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY"; then
  ok "Container exists"
  az storage container set-permission --name "$CONTAINER" \
    --public-access "$PUBLIC_ACCESS_FLAG" \
    --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" -o none
else
  az storage container create --name "$CONTAINER" \
    --public-access "$PUBLIC_ACCESS_FLAG" \
    --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" -o none
  ok "Created container"
fi

# ---- 4. Upload the model with an immutable cache header -------------------
# The blob is versioned by filename, so it is safe to cache forever.
CACHE_CONTROL="public, max-age=31536000, immutable"
if [[ "$SKIP_UPLOAD" == "true" ]]; then
  warn "SKIP_UPLOAD=true — not uploading $BLOB_NAME"
else
  [[ -f "$MODEL_FILE" ]] || die "Model file not found: $MODEL_FILE (set MODEL_FILE or SKIP_UPLOAD=true)"
  log "Uploading '$MODEL_FILE' -> $CONTAINER/$BLOB_NAME (this can take a while)"
  az storage blob upload --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" \
    --container-name "$CONTAINER" --name "$BLOB_NAME" --file "$MODEL_FILE" \
    --content-cache-control "$CACHE_CONTROL" --overwrite --no-progress -o none
  ok "Uploaded and set Cache-Control: $CACHE_CONTROL"
fi

# ---- 5. Front Door profile + endpoint -------------------------------------
log "Ensuring Front Door profile '$FRONTDOOR_PROFILE' (Standard)"
if exists az afd profile show --profile-name "$FRONTDOOR_PROFILE" -g "$RESOURCE_GROUP"; then
  ok "Profile exists"
else
  az afd profile create --profile-name "$FRONTDOOR_PROFILE" -g "$RESOURCE_GROUP" \
    --sku Standard_AzureFrontDoor -o none
  ok "Created profile"
fi

log "Ensuring endpoint '$FRONTDOOR_ENDPOINT'"
if exists az afd endpoint show --endpoint-name "$FRONTDOOR_ENDPOINT" \
    --profile-name "$FRONTDOOR_PROFILE" -g "$RESOURCE_GROUP"; then
  ok "Endpoint exists"
else
  az afd endpoint create --endpoint-name "$FRONTDOOR_ENDPOINT" \
    --profile-name "$FRONTDOOR_PROFILE" -g "$RESOURCE_GROUP" \
    --enabled-state Enabled -o none
  ok "Created endpoint"
fi

ENDPOINT_HOST="$(az afd endpoint show --endpoint-name "$FRONTDOOR_ENDPOINT" \
  --profile-name "$FRONTDOOR_PROFILE" -g "$RESOURCE_GROUP" \
  --query hostName -o tsv)"

# ---- 6. Origin group + blob origin ----------------------------------------
ORIGIN_GROUP="blob-og"
ORIGIN_NAME="blob"
log "Ensuring origin group '$ORIGIN_GROUP'"
if exists az afd origin-group show --origin-group-name "$ORIGIN_GROUP" \
    --profile-name "$FRONTDOOR_PROFILE" -g "$RESOURCE_GROUP"; then
  ok "Origin group exists"
else
  az afd origin-group create --origin-group-name "$ORIGIN_GROUP" \
    --profile-name "$FRONTDOOR_PROFILE" -g "$RESOURCE_GROUP" \
    --probe-request-type HEAD --probe-protocol Https \
    --probe-path "/$CONTAINER/$BLOB_NAME" \
    --probe-interval-in-seconds 120 --sample-size 4 \
    --successful-samples-required 3 --additional-latency-in-milliseconds 50 -o none
  ok "Created origin group"
fi

log "Ensuring origin '$ORIGIN_NAME' -> $BLOB_HOST"
if exists az afd origin show --origin-name "$ORIGIN_NAME" \
    --origin-group-name "$ORIGIN_GROUP" --profile-name "$FRONTDOOR_PROFILE" \
    -g "$RESOURCE_GROUP"; then
  ok "Origin exists"
else
  az afd origin create --origin-name "$ORIGIN_NAME" \
    --origin-group-name "$ORIGIN_GROUP" --profile-name "$FRONTDOOR_PROFILE" \
    -g "$RESOURCE_GROUP" --host-name "$BLOB_HOST" \
    --origin-host-header "$BLOB_HOST" --https-port 443 \
    --priority 1 --weight 1000 --enabled-state Enabled \
    --enforce-certificate-name-check true -o none
  ok "Created origin"
fi

# ---- 7. Route: /models/* cached over HTTPS --------------------------------
ROUTE_NAME="models-route"
log "Ensuring route '$ROUTE_NAME' (/$CONTAINER/*)"
if exists az afd route show --route-name "$ROUTE_NAME" \
    --endpoint-name "$FRONTDOOR_ENDPOINT" --profile-name "$FRONTDOOR_PROFILE" \
    -g "$RESOURCE_GROUP"; then
  ok "Route exists"
else
  az afd route create --route-name "$ROUTE_NAME" \
    --endpoint-name "$FRONTDOOR_ENDPOINT" --profile-name "$FRONTDOOR_PROFILE" \
    -g "$RESOURCE_GROUP" --origin-group "$ORIGIN_GROUP" \
    --supported-protocols Https --https-redirect Enabled \
    --forwarding-protocol HttpsOnly --link-to-default-domain Enabled \
    --patterns-to-match "/$CONTAINER/*" \
    --enable-caching true --query-string-caching-behavior IgnoreQueryString -o none
  ok "Created route"
fi

CDN_URL="https://${ENDPOINT_HOST}/${CONTAINER}/${BLOB_NAME}"

# ---- 8. Summary + verification -------------------------------------------
cat <<EOF

$(printf '\033[1;32mFront Door is provisioned.\033[0m')

  Tokenless CDN URL:
    $CDN_URL

  Build the app with:
    --dart-define=GEMMA_MODEL_CDN_URL=$CDN_URL

  (No SAS/token needed. See lib/main.dart _gemmaService.)

EOF

if [[ "$PUBLIC_CONTAINER" != "true" ]]; then
  warn "Container is PRIVATE. Front Door will 403 until you grant origin access"
  warn "(e.g. a Front Door rule appending a SAS, or a Private Link origin)."
fi

log "Probing the CDN URL (first-time propagation takes up to ~20 min; a fresh"
log "404 with X-Cache=CONFIG_NOCACHE just means the edge config isn't live yet)..."
CODE="$(curl -s -o /dev/null -w '%{http_code}' -I "$CDN_URL" || echo 000)"
XCACHE="$(curl -s -D - -o /dev/null "$CDN_URL" -r 0-0 2>/dev/null \
  | tr -d '\r' | awk -F': ' 'tolower($1)=="x-cache"{print $2}')"
printf '  HTTP %s  X-Cache=%s\n' "$CODE" "${XCACHE:-<none>}"
if [[ "$CODE" == "200" || "$CODE" == "206" ]]; then
  ok "Edge is live."
else
  warn "Not live yet (HTTP $CODE). Wait ~20 min, then verify with:"
  warn "  curl -I $CDN_URL"
  warn "AVOID re-running config changes back-to-back — that resets the rollout"
  warn "clock (up to ~40 min per the Azure Front Door FAQ)."
fi

ok "Done."
