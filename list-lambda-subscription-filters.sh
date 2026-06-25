#!/usr/bin/env bash
set -euo pipefail

# Columns widths
W_LG=50
W_FN=30
W_DEST=70
W_PAT=30

printf "%-${W_LG}s  %-${W_FN}s  %-${W_DEST}s  %s\n" \
  "LOG GROUP" "FILTER NAME" "DESTINATION ARN" "FILTER PATTERN"
printf "%-${W_LG}s  %-${W_FN}s  %-${W_DEST}s  %s\n" \
  "$(printf '%0.s-' $(seq 1 $W_LG))" \
  "$(printf '%0.s-' $(seq 1 $W_FN))" \
  "$(printf '%0.s-' $(seq 1 $W_DEST))" \
  "$(printf '%0.s-' $(seq 1 $W_PAT))"

total_groups=0
total_filters=0
next_token=""

while true; do
  if [[ -n "$next_token" ]]; then
    response=$(aws logs describe-log-groups \
      --log-group-name-prefix "/aws/lambda/" \
      --next-token "$next_token" \
      --output json)
  else
    response=$(aws logs describe-log-groups \
      --log-group-name-prefix "/aws/lambda/" \
      --output json)
  fi

  log_groups=$(echo "$response" | jq -r '.logGroups[].logGroupName')
  next_token=$(echo "$response" | jq -r '.nextToken // empty')

  while IFS= read -r log_group; do
    [[ -z "$log_group" ]] && continue
    total_groups=$((total_groups + 1))

    filters=$(aws logs describe-subscription-filters \
      --log-group-name "$log_group" \
      --output json | jq -c '.subscriptionFilters[]?')

    while IFS= read -r filter; do
      [[ -z "$filter" ]] && continue
      total_filters=$((total_filters + 1))

      filter_name=$(echo "$filter" | jq -r '.filterName')
      dest_arn=$(echo "$filter"   | jq -r '.destinationArn')
      pattern=$(echo "$filter"    | jq -r '.filterPattern')
      [[ -z "$pattern" ]] && pattern="(none)"

      printf "%-${W_LG}s  %-${W_FN}s  %-${W_DEST}s  %s\n" \
        "$log_group" "$filter_name" "$dest_arn" "$pattern"
    done <<< "$filters"
  done <<< "$log_groups"

  [[ -z "$next_token" ]] && break
done

echo ""
echo "Scanned $total_groups log group(s), found $total_filters subscription filter(s)."
