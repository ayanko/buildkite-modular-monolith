#!/bin/bash

set -eu

###############################################################################

readonly MODULAR_ROOTS=(gems)
readonly GH_REPO_URL_REGEXP='^git\@github\.com\:(.*)\.git$'

###############################################################################

function error_exit {
  echo "${1:-"Unknown Error"}" >&2
  exit 1
}

function get_gh_api_base {
  if [[ ${BUILDKITE_REPO} =~ ${GH_REPO_URL_REGEXP} ]]; then
    echo "https://api.github.com/repos/${BASH_REMATCH[1]}"
  else
    error_exit "Can't parse BUILDKITE_REPO=${BUILDKITE_REPO}"
  fi
}

function gh_api_request {
  local url="${GH_API_BASE}/$1"
  local output=$(
    curl -s \
    -H "Authorization: token ${GH_TOKEN}" \
    -w "%{http_code}" \
    -X GET "$url"
  )

  local code=$(
    echo "$output" | tail -n1
  )

  local body=$(
    echo "$output" | sed '$ d'
  )

  if [[ $code != 200 ]]; then
    error_exit "GH API ERROR: url=$url code=$code body=$body"
  fi

  echo "$body"
}

function get_content {
  local path="$1"
  local branch="$2"
  gh_api_request "contents/$path?ref=$branch"
}

function get_dir_sha {
  local content="$1"
  local dir="$2"
  echo "$content" | jq -r ".[] | select(.type==\"dir\" and .path==\"$dir\") | .sha"
}

###############################################################################

readonly GH_API_BASE=$(get_gh_api_base)

enforce_all=false
if [[ "$BUILDKITE_BRANCH" == "master" ]]; then
  enforce_all=true
fi
readonly enforce_all

cat .buildkite/pipeline.yml

for root in ${MODULAR_ROOTS[@]}; do
  if [[ $enforce_all == false ]]; then
    master_content=$(get_content "$root" "master")
    branch_content=$(get_content "$root" "$BUILDKITE_BRANCH")
  fi

  for path in $root/*; do
    if [[ $enforce_all == true ]]; then
      dir_changed=true
    else
      master_dir_sha=$(get_dir_sha "$master_content" "$path")
      branch_dir_sha=$(get_dir_sha "$branch_content" "$path")
      if [[ "$master_dir_sha" != "$branch_dir_sha" ]]; then
        dir_changed=true
      else
        dir_changed=false
      fi
    fi

    if [[ $dir_changed == true ]]; then
      cat "$path/.buildkite/pipeline.yml"
    else
      echo "  - label: \":point_up:\""
      echo "    command: echo \"Skip ${path}\""
    fi
  done
done
