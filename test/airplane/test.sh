#!/bin/bash

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

echo -e "airplane CLI is installed at: $(which airplane)"

check "check airplane CLI is installed" bash -c "airplane --version"

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults