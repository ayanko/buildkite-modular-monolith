#!/bin/bash

set -eu

GH_API_TOKEN="${GH_TOKEN}"
GH_API_REPO="ayanko/buildkite-modular-monolith"
GH_API_BRANCH="${BUILDKITE_BRANCH}"

echo "steps:"

for gem in gems/*; do
  count=$(curl -s \
    -H "Authorization: token ${GH_TOKEN}" \
    -X GET \
    "https://api.github.com/repos/${GH_API_REPO}/commits?sha=${GH_API_BRANCH}&path=${gem}&per_page=1" \
    | jq '. | length'
  )

  if [[ $count == "1" ]]; then
    echo "  - name: \":rspec:\""
    echo "    command: \"cd ${gem} && bundle install && rake spec\""
    echo "    timeout_in_minutes: 10"
    echo "    retry:"
    echo "      automatic: true"
    echo "    plugins:"
    echo "      docker-compose#v3.3.0:"
    echo "        run: test"
    echo "        pull-retries: 4"
  fi
done
