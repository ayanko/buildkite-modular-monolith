#!/bin/bash

set -eu

GH_API_TOKEN="${GH_TOKEN}"
GH_API_REPO="ayanko/buildkite-modular-monolith"
GH_API_BRANCH="${BUILDKITE_BRANCH}"

changed_gems=()

for gem in gems/*; do
  master_sha=$(curl -s \
    -H "Authorization: token ${GH_TOKEN}" \
    -X GET \
    "https://api.github.com/repos/${GH_API_REPO}/commits?sha=master&path=${gem}&per_page=1" \
    | jq '.[0].sha'
  )

  current_sha=$(curl -s \
    -H "Authorization: token ${GH_TOKEN}" \
    -X GET \
    "https://api.github.com/repos/${GH_API_REPO}/commits?sha=${GH_API_BRANCH}&path=${gem}&per_page=1" \
    | jq '.[0].sha'
  )

  if [[ "${current_sha}" != "${master_sha}" ]]; then
    changed_gems+=(${gem})
  fi
done

if [[ ${#changed_gems[@]} -eq 0 ]]; then
  echo "steps: []"
else
  echo "steps:"
  for gem in ${changed_gems[@]}; do
    echo "  - name: \":rspec:\""
    echo "    command: \"cd ${gem} && bundle install && rake spec\""
    echo "    timeout_in_minutes: 10"
    echo "    retry:"
    echo "      automatic: true"
    echo "    plugins:"
    echo "      docker-compose#v3.3.0:"
    echo "        run: test"
    echo "        pull-retries: 4"
  done
fi
