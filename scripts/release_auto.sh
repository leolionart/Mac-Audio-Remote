#!/bin/bash
# Quick command to run automated release
# Usage: ./scripts/release_auto.sh

exec "$(dirname "$0")/../.claude/skills/release/auto_release.sh"
