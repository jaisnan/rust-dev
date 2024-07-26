#!/bin/bash

# Set the working directories
VERIFY_RUST_STD_DIR="/tmp/verify-rust-std"
KANI_DIR="/tmp/kani"

# Checkout your local repository
echo "Checking out local repository..."
echo
cd "$VERIFY_RUST_STD_DIR"

# Checkout the Kani repository
echo "Checking out Kani repository..."
echo
git clone --depth 1 -b features/verify-rust-std https://github.com/model-checking/kani.git "$KANI_DIR"

# Setup dependencies for Kani
echo "Setting up dependencies for Kani..."
echo
cd "$KANI_DIR"
./scripts/setup/ubuntu/install_deps.sh

# Build Kani
echo "Building Kani..."
echo
cargo build-dev --release
echo "$(pwd)/scripts" >> $PATH

# Run tests
echo "Running tests..."
echo
cd "$VERIFY_RUST_STD_DIR"
kani verify-std -Z unstable-options ./library --target-dir "$RUNNER_TEMP" -Z function-contracts -Z mem-predicates -Z ptr-to-ref-cast-checks
RUST_BACKTRACE=1

echo "Tests completed."
echo

# Clean up the Kani directory (optional)
# rm -rf "$KANI_DIR"
