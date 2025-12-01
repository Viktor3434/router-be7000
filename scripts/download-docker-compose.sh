#!/bin/sh

set -e

# Variables
INSTALL_DIR="$1"
BINARY_PATH="$INSTALL_DIR/docker-compose"
DOWNLOAD_URL="https://github.com/docker/compose/releases/download/v2.27.3/docker-compose-linux-aarch64"

# Checks
[ ! -w "$INSTALL_DIR" ] && echo "Error: No write permissions" && exit 1
! command -v docker >/dev/null && echo "Error: Docker is not installed" && exit 1
! docker info >/dev/null && echo "Error: Docker daemon is not running" && exit 1

# Downloading
if [ -f $INSTALL_DIR/docker-compose ] ; then
    echo
    echo '####'
    echo "# Docker compose exist!"
    echo '####'
    echo
    # Show ver
    echo "Version:"
    $BINARY_PATH --version || exit 1

else
  echo "Downloading docker-compose..."
  curl -f -L "$DOWNLOAD_URL" -o "$BINARY_PATH" || exit 1
  chmod +x "$BINARY_PATH" || exit 1

  # Show ver
  echo "Version:"
  $BINARY_PATH --version || exit 1

  # Test
  echo "Quick functionality test..."
  mkdir -p /tmp/test-compose
  cd /tmp/test-compose

  cat > docker-compose.yml << 'EOF'
version: '3'
services:
  test:
    image: hello-world
EOF

  $BINARY_PATH up

  # Clean
  $BINARY_PATH down 2>/dev/null || true
  rm -rf /tmp/test-compose
  docker rmi hello-world:latest
fi
