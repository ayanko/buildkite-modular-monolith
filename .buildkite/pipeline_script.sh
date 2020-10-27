#!/bin/bash

set -euo pipefail

###############################################################################

declare -r GH_API_BASE_URL="https://api.github.com/repos"
declare -r GH_OWNER_REPO_REGEXP='^git\@github\.com\:(.*)\.git$'
declare -r DEFAULT_BASE_BRANCH='master'
declare -r PIPELINE_FILE='.buildkite/pipeline.yml'
declare -r HIGH_PRIORITY_SCRIPT='.buildkite/high_priority_instructions.yml'
declare -r HIGH_PRIORITY_LABEL='high-priority-build'
declare -r MODULAR_ROOTS=(gems)

###############################################################################

function gh_api_request {
  local url="$GH_API_BASE_URL/$GH_OWNER_REPO/$1"
  local response
  local code
  local body

  response=$(
    curl -s \
    -H "Authorization: token ${GH_TOKEN}" \
    -w "%{http_code}" \
    -X GET "$url"
  )
  code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$ d')

  case $code in
    200)
      _result="$body"
      ;;
    500)
      _result=""
      ;;
    *)
      echo "GH API ERROR: url=$url code=$code body=$body"
      exit 1
  esac
}

function is_high_priority_build {
  local json="$1"
  echo "$json" | jq ".[] | select(.name == \"$HIGH_PRIORITY_LABEL\") | any"
}

function is_path_changed {
  local json="$1"
  local dir="$2"
  echo "$json" | jq "first(.files[] | select(.filename | startswith(\"$dir\"))) | any"
}

###############################################################################

# declare owner/repo pair
if [[ ${BUILDKITE_REPO} =~ $GH_OWNER_REPO_REGEXP ]]; then
  declare -r GH_OWNER_REPO="${BASH_REMATCH[1]}"
else
  echo "Can't parse BUILDKITE_REPO=${BUILDKITE_REPO}"
  exit 1
fi

# declare base branch
if [[ -n "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" ]]; then
  declare -r base_branch="$BUILDKITE_PULL_REQUEST_BASE_BRANCH"
else
  declare -r base_branch="$DEFAULT_BASE_BRANCH"
fi

# declare current branch
declare -r current_branch="$BUILDKITE_BRANCH"

# enforce_changes if current branch is base one
if [[ "$current_branch" == "$base_branch" ]]; then
  declare -r enforce_changes=true
else
  declare -r enforce_changes=false
fi

# general retun from functions
declare _result

###############################################################################

# perform GH pull labels request to set high_priority
declare high_priority=false
if [[ "$BUILDKITE_PULL_REQUEST" != "false" ]]; then
  gh_api_request "issues/${BUILDKITE_PULL_REQUEST}/labels"
  if [[ -n "$_result" ]];then
    high_priority=$(is_high_priority_build "$_result")
  fi
fi

# perform GH compare request
declare compare_json=""
if [[ $enforce_changes == false ]]; then
  gh_api_request "compare/$base_branch...$current_branch"
  if [[ -n "$_result" ]];then
    compare_json="$_result"
  fi
fi

# print main steps
pipeline=$(cat $PIPELINE_FILE)

for root in ${MODULAR_ROOTS[@]}; do
  for path in $root/*; do
    if [[ -n "$compare_json" ]]; then
      dir_changed=$(is_path_changed "$compare_json" "$path")
    else
      dir_changed=true
    fi

    if [[ $dir_changed == true ]]; then
      pipeline=$(echo "$pipeline" | yq m - "${path}/${PIPELINE_FILE}" -a append)
    else
      pipeline=$(echo "$pipeline" | yq w - 'steps[+].label' ":point_up: Skip ${path}")
      pipeline=$(echo "$pipeline" | yq w - 'steps[-1].command' 'echo true')
    fi
  done
done

if [[ $high_priority == true ]];then
  pipeline=$(echo "$pipeline" | yq w - -s $HIGH_PRIORITY_SCRIPT)
fi

echo "$pipeline"
