#!/usr/bin/env bash
# Preflight checks before the first terraform apply.
# Read-only.

set -uo pipefail

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  [ok]   %s\n' "$*"; }
warn() { printf '  [warn] %s\n' "$*"; }
fail() { printf '  [fail] %s\n' "$*"; }

say "== AWS CLI =="
if ! command -v aws >/dev/null 2>&1; then
  fail "aws CLI not found in PATH"
  exit 1
fi
ok "$(aws --version 2>&1)"

say "== Identity =="
if ! IDENTITY=$(aws sts get-caller-identity --output json 2>&1); then
  fail "No usable credentials. Run 'aws configure' or 'aws configure sso' first."
  say "$IDENTITY"
  exit 1
fi
ACCOUNT_ID=$(printf '%s' "$IDENTITY" | python -c 'import json,sys; print(json.load(sys.stdin)["Account"])')
ARN=$(printf '%s' "$IDENTITY" | python -c 'import json,sys; print(json.load(sys.stdin)["Arn"])')
ok "account $ACCOUNT_ID"
ok "principal $ARN"
case "$ARN" in
  *:root) warn "You are using the root user. Fine for bootstrap, but create an admin role or Identity Center user and stop using root afterwards (AC-6(5))." ;;
esac

say "== Region =="
ok "region $REGION"
case "$REGION" in
  us-east-1|us-east-2|us-west-1|us-west-2) ok "US commercial region, FIPS endpoints available" ;;
  *) warn "Not a US region. FIPS endpoints are a US-region feature; set region = us-east-1 in tfvars." ;;
esac

say "== AWS Organizations =="
if ORG=$(aws organizations describe-organization --output json 2>/dev/null); then
  MGMT=$(printf '%s' "$ORG" | python -c 'import json,sys; print(json.load(sys.stdin)["Organization"]["MasterAccountId"])')
  ORG_ID=$(printf '%s' "$ORG" | python -c 'import json,sys; print(json.load(sys.stdin)["Organization"]["Id"])')
  FEATURES=$(printf '%s' "$ORG" | python -c 'import json,sys; print(json.load(sys.stdin)["Organization"]["FeatureSet"])')
  if [ "$MGMT" = "$ACCOUNT_ID" ]; then
    ok "this account is the management account of $ORG_ID (feature set: $FEATURES)"
    say "       tfvars: enable_organizations = true, create_organization = false"
    [ "$FEATURES" = "ALL" ] || warn "Feature set is not ALL; SCPs require all features. Enable in the console."
  else
    warn "this account is a MEMBER of $ORG_ID (management account $MGMT)"
    say "       tfvars: enable_organizations = false"
  fi
else
  ok "no organization yet; Terraform can create one"
  say "       tfvars: enable_organizations = true, create_organization = true"
fi

say "== IAM Identity Center =="
if INSTANCES=$(aws sso-admin list-instances --region "$REGION" --output json 2>/dev/null); then
  COUNT=$(printf '%s' "$INSTANCES" | python -c 'import json,sys; print(len(json.load(sys.stdin).get("Instances",[])))')
  if [ "$COUNT" -gt 0 ]; then
    ok "Identity Center instance found in $REGION"
    say "       tfvars: enable_identity_center = true"
  else
    warn "Identity Center not enabled in $REGION. Enable it in the console (free), then set enable_identity_center = true."
  fi
else
  warn "Could not query Identity Center (missing permission or not enabled)."
fi

# Runs an AWS CLI call and extracts a value with a python expression over the
# parsed JSON (bound to d).
aws_json() {
  local expr="$1"; shift
  local out
  if ! out=$(aws "$@" --output json 2>&1); then
    printf 'ERROR: %s' "$(printf '%s' "$out" | tail -1)"
    return 1
  fi
  printf '%s' "$out" | python -c "import json,sys
try:
    d=json.load(sys.stdin)
except Exception as e:
    print('ERROR: non-JSON response'); sys.exit(1)
print($expr)"
}

say "== Existing audit infrastructure =="
TRAILS=$(aws_json '", ".join(t["Name"] for t in d.get("Trails",[])) or "none"' cloudtrail list-trails --region "$REGION")
case "$TRAILS" in
  ERROR*) warn "cloudtrail: $TRAILS" ;;
  *)      ok "existing trails: $TRAILS" ;;
esac
RECORDERS=$(aws_json '", ".join(r["name"] for r in d.get("ConfigurationRecorders",[])) or "none"' configservice describe-configuration-recorders --region "$REGION")
case "$RECORDERS" in
  ERROR*) warn "config: $RECORDERS" ;;
  none)   ok "no Config recorder in $REGION" ;;
  *)      warn "Config recorder '$RECORDERS' already exists in this region (limit: one). Import it or delete it before apply." ;;
esac

say "== IAM users (target: zero) =="
USERS=$(aws_json 'len(d.get("Users",[]))' iam list-users)
case "$USERS" in
  ERROR*) warn "iam: $USERS" ;;
  0)      ok "no IAM users" ;;
  *)      warn "$USERS IAM user(s) exist. Plan their migration to Identity Center." ;;
esac

say
say "Preflight complete."
