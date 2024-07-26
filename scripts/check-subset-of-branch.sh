#!/bin/bash

# Set the branch names
MAIN_BRANCH="main"
FEATURE_BRANCH="features/verify-rust-std"

# Get the merge base commit
MERGE_BASE=$(git merge-base "$MAIN_BRANCH" "$FEATURE_BRANCH")

# Check if all commits in the feature branch are present in the main branch
if git rev-list --ancestry-path "$MERGE_BASE..$FEATURE_BRANCH" >/dev/null; then
    echo "The '$FEATURE_BRANCH' branch is a subset of the '$MAIN_BRANCH' branch."
else
    echo "The '$FEATURE_BRANCH' branch is not a subset of the '$MAIN_BRANCH' branch."
fi
