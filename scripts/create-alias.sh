#!/bin/sh

# Create backup only if it doesn't exist
if [ ! -f /etc/profile.orig ]; then
    cp -a /etc/profile /etc/profile.orig
    echo "Created backup: /etc/profile.orig"
else
    echo "Backup already exists: /etc/profile.orig"
fi

DOCKER_PATH=$1

[ ! -d "${DOCKER_PATH}" ] && echo "Error: Directory \"${DOCKER_PATH}\" does not exist." && exit 1

echo "[INFO] docker-binaries: $DOCKER_PATH"

# Check if the block already exists in profile
if grep -q "CUSTOM_DOCKER_PATH_BLOCK_START" /etc/profile; then
    echo "Found existing docker path block in /etc/profile"
    echo "Updating the path in the existing block..."
    
    # Remove the existing block
    sed -i '/### CUSTOM_DOCKER_PATH_BLOCK_START/,/### CUSTOM_DOCKER_PATH_BLOCK_END/d' /etc/profile
fi

# Add the new block with the current path
cat >> /etc/profile << EOF

### CUSTOM_DOCKER_PATH_BLOCK_START
# Customize PATH for docker binaries
if [ -d "$DOCKER_PATH" ]; then
    export PATH="$DOCKER_PATH:\$PATH"
fi
### CUSTOM_DOCKER_PATH_BLOCK_END
EOF

echo "Docker path configuration updated in profile: $DOCKER_PATH"
echo "You can reload with: source /etc/profile"
