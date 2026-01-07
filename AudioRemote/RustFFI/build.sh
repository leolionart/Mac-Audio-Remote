#!/bin/bash
set -e

echo "🦀 Building Rust FFI library..."

cd "$(dirname "$0")"

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Error: Rust/Cargo not found. Install from https://rustup.rs"
    exit 1
fi

# Build for macOS targets
echo "📦 Building for x86_64-apple-darwin..."
cargo build --release --target x86_64-apple-darwin

echo "📦 Building for aarch64-apple-darwin..."
cargo build --release --target aarch64-apple-darwin

# Create universal binary using lipo
echo "🔗 Creating universal binary..."
lipo -create \
    target/x86_64-apple-darwin/release/libaudioremote_ffi.a \
    target/aarch64-apple-darwin/release/libaudioremote_ffi.a \
    -output libaudioremote_ffi.a

echo "✅ Universal static library created: libaudioremote_ffi.a"

# Verify the architectures
echo "🔍 Verifying architectures..."
lipo -info libaudioremote_ffi.a
