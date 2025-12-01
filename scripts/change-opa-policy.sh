#!/bin/sh

OPA_POLICY_FILE="/var/run/docker/opa/authz.rego"
BACKUP_FILE="${OPA_POLICY_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

cp -a "$OPA_POLICY_FILE" "$BACKUP_FILE"

awk '
found_binds && /not regex\.match/ {
    print "    not regex.match(\"^(/mnt/usb-[^:]+|/var/run/docker.sock):[^:]+(:ro|:rw)?$\", m)"
    found_binds = 0
    next
}

/m = input\.Body\.HostConfig\.Binds\[_\]/ {
    found_binds = 1
    print
    next
}

{ print }
' "$OPA_POLICY_FILE" > "${OPA_POLICY_FILE}.tmp" && mv "${OPA_POLICY_FILE}.tmp" "$OPA_POLICY_FILE"

echo "Replace done"
