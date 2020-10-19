#!/bin/bash

# Script to generate a simple changelog for the current release with
# commit messages taken between the current tag and the previous one.

# Github base url for linking to commits and releases
proj_url="https://github.com/4bitfocus/LootRollLedger"

# This should match your version tag naming scheme
ver_match="v[0-9]*[0-9]"

curr_tag=$(git describe --tags --abbrev=0 --match ${ver_match})
prev_tag=$(git describe --tags --abbrev=0 ${curr_tag}^)
date_str=$(git log -1 --format=%ad --date=short ${curr_tag})
echo "Changes made to ${curr_tag} (${date_str}):"
echo "  - [Full ChangeLog](${proj_url}/commits/${curr_tag})"
echo "  - [Previous Releases](${proj_url}/releases)"
# %s is commit subject, %h is the short commit hash. Add %an to include the author name
git log --no-merges --pretty="%s [%h]" ${prev_tag}...${curr_tag} \
  | sed 's/^/  - /' \
  | sed 's/^\([-_a-zA-Z0-9]*\):/**\1**:/'
