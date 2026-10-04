#!/usr/bin/env bash
# Empties an S3 bucket that has Object Lock in GOVERNANCE mode, including all
# object versions and delete markers, by bypassing governance retention.

set -euo pipefail

BUCKET="${1:?bucket name required}"
PROFILE="${2:-${AWS_PROFILE:-default}}"

echo "Purging s3://$BUCKET (profile $PROFILE) with governance bypass"

total=0
while true; do
  versions=$(aws s3api list-object-versions --bucket "$BUCKET" --profile "$PROFILE" --max-items 1000 --output json 2>/dev/null \
    | python -c '
import json, sys
d = json.load(sys.stdin)
objs = [{"Key": v["Key"], "VersionId": v["VersionId"]} for v in d.get("Versions", [])]
objs += [{"Key": m["Key"], "VersionId": m["VersionId"]} for m in d.get("DeleteMarkers", [])]
print(json.dumps({"Objects": objs[:1000], "Quiet": True}))
')
  count=$(printf '%s' "$versions" | python -c 'import json,sys; print(len(json.load(sys.stdin)["Objects"]))')
  if [ "$count" -eq 0 ]; then
    break
  fi
  # Relative path on purpose: the Windows AWS CLI cannot read Git Bash /tmp
  # paths.
  tmp="./.purge-$$.json"
  printf '%s' "$versions" > "$tmp"
  aws s3api delete-objects --bucket "$BUCKET" --profile "$PROFILE" --bypass-governance-retention --delete "file://$tmp" --output json >/dev/null
  rm -f "$tmp"
  total=$((total + count))
  echo "  deleted $count versions (running total $total)"
done

echo "Done. $total object versions removed from $BUCKET."
