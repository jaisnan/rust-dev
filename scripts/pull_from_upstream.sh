#!/bin/bash

set -eux

HOME_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Set variables
REPO_OWNER="model-checking"
REPO_NAME="kani"
BRANCH_NAME="features/verify-rust-std"
TOOLCHAIN_FILE="rust-toolchain.toml"

# Set base
BASE_REPO="https://github.com/model-checking/verify-rust-std.git"

# Create a temporary directory
temp_home_dir=$(mktemp -d)

# Clone the repository into the temporary directory
git clone "$BASE_REPO" "$temp_home_dir"
cd $temp_home_dir

# Function to extract commit hash and date from rustc version
get_rustc_info() {
    local rustc_output=$(rustc --version --verbose)
    local commit_hash=$(echo "$rustc_output" | grep 'commit-hash' | awk '{print $2}')
    local commit_date=$(echo "$rustc_output" | grep 'commit-date' | awk '{print $2}')

    if [ -z "$commit_hash" ] || [ -z "$commit_date" ]; then
        echo "Error: Could not extract commit hash or date from rustc output."
        exit 1
    fi

    echo "$commit_hash:$commit_date"
}

read_toolchain_date() {
    local toolchain_file=$TOOLCHAIN_FILE

    if [ ! -f "$toolchain_file" ]; then
        echo "Error: $toolchain_file not found in the working directory." >&2
        return 1
    fi

    local toolchain_date
    toolchain_date=$(grep -oP 'channel.*=.*"nightly-' ./rust-toolchain.toml | sed -E 's/.*nightly-([0-9-]+).*/\1/' "$toolchain_file")

    if [ -z "$toolchain_date" ]; then
        echo "Error: Could not extract date from $toolchain_file" >&2
        return 1
    fi

    echo "$toolchain_date"
}

# Check if a path is provided as an argument
if [ $# -eq 1 ]; then
    REPO_PATH="$1"
    echo "Using provided repository path: $REPO_PATH"

    # Ensure the provided path exists and is a git repository
    if [ ! -d "$REPO_PATH/.git" ]; then
        echo "Error: Provided path is not a git repository."
        exit 1
    fi

    pushd $REPO_PATH
    git switch $BRANCH_NAME

    # Get rustc info
    RUSTC_INFO=$(get_rustc_info)
    TOOLCHAIN_DATE=$(read_toolchain_date)

    if [ $? -ne 0 ]; then
    exit 1
    fi
    COMMIT_HASH=$(echo $RUSTC_INFO | cut -d':' -f1)
    RUST_DATE=$(echo $RUSTC_INFO | cut -d':' -f2)
    popd
else
    # Create a temporary directory
    TMP_DIR=$(mktemp -d)
    echo "Created temporary directory: $TMP_DIR"

    # Clone the repository into the temporary directory
    echo "Cloning repository..."
    git clone --branch "$BRANCH_NAME" --depth 1 "https://github.com/$REPO_OWNER/$REPO_NAME.git" "$TMP_DIR/repo"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone the repository."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Get rustc info
    RUSTC_INFO=$(get_rustc_info)
    COMMIT_HASH=$(echo $RUSTC_INFO | cut -d':' -f1)
    RUST_DATE=$(echo $RUSTC_INFO | cut -d':' -f2)

    # Clean up the temporary directory
    rm -rf "$TMP_DIR"
fi

if [ -z "$COMMIT_HASH" ]; then
    echo "Could not find commit hash in rust-toolchain.toml"
    exit 1
fi

if [ -z "$RUST_DATE" ]; then
    echo "Could not find date in rust-toolchain.toml"
    exit 1
fi

echo "Rust commit hash found: $COMMIT_HASH"
echo "Rust date found: $TOOLCHAIN_DATE"

# Ensure we have the rust-lang/rust repository as a remote named "upstream"
if ! git remote | grep -q '^upstream$'; then
    echo "Adding rust-lang/rust as upstream remote"
    git remote add upstream https://github.com/rust-lang/rust.git
fi

cd $temp_home_dir

# The checkout and pull itself needs to happen in sync with features/verify-rust-std
# Often times rust is going to be ahead of kani in terms of the toolchain, and both need to point to
# the same commit
SYNC_BRANCH="sync-$TOOLCHAIN_DATE" && echo "--- Fork branch: ${SYNC_BRANCH} ---"
# # 1. Update the upstream/master branch with the latest changes
git fetch upstream
git checkout $COMMIT_HASH

# # 2. Update the subtree branch
# This command will take a while again
git subtree split --prefix=library --onto subtree/library -b subtree/library
# 3. Update main
git fetch origin
git checkout -b ${SYNC_BRANCH} origin/main

git subtree merge --prefix=library subtree/library --squash
