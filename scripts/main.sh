#!/bin/sh
set -e


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create directories
create_directories() {
    log_info "Creating dir"
    if [ ! -d "$1" ] ;then 
        mkdir -p "$1" || log_error "Create dir \"$1\" error"
        log_success "Dir created: \"$1\""
    else
        log_warning "Error: Directory \"$1\" is exist."
    fi
}

# Download config file from GitHub
download_file() {
    local from="$1"
    local to_dir="$2"
    local filename=$(echo "$from" | awk -F/ '{print $NF}')

    log_info "Downloading $filename..."
    if curl -s -L -o "$to_dir/$filename" "$from"; then
        log_success "Downloaded $filename"
    else
        log_error "Failed to download $filename"
        return 1
    fi
}

# Run change-opa-policy script
run_opa_policy_fix() {
    log_info "Running OPA policy fix..."
    
    if [ ! -f "${OPA_POLICY_FILE}" ]; then
        log_error "OPA policy file not found: ${OPA_POLICY_FILE}"
        log_error "Please edit OPA_POLICY_FILE variable in main script"
        return 1
    fi
    
    if "${SCRIPTS_DIR}/change-opa-policy.sh" "${OPA_POLICY_FILE}"; then
        log_success "OPA policy fixed successfully"
    else
        log_error "Failed to fix OPA policy"
        return 1
    fi
}



# Run create-alias script
run_create_alias() {
    log_info "Creating Docker aliases..."
    
    if "${SCRIPTS_DIR}/create-alias.sh" "${DOCKER_PATH}"; then
        log_success "Docker aliases created successfully"
        # Reload profile to apply aliases
        source /etc/profile 2>/dev/null || true
    else
        log_error "Failed to create Docker aliases"
        return 1
    fi
}

# Run download-docker-compose script
run_download_docker_compose() {
    log_info "Downloading Docker Compose..."
    
    if "${SCRIPTS_DIR}/download-docker-compose.sh" "${DOCKER_PATH}"; then
        log_success "Docker Compose exist or successfully downloaded"
    else
        log_error "Failed to download Docker Compose"
        return 1
    fi
}

generate_values_mustache() {
    log_info "Generate file with values for mustache..."

    cat > ${TEMPLATES_DIR}/values.mustache << EOF
HTTP_PROXY_IP_ADDR: ${HTTP_PROXY_IP_ADDR}
HTTP_PROXY_PORT: ${HTTP_PROXY_PORT}
BYE_SOCS_PORT: ${BYE_SOCS_PORT}
AUTOCONF_PORT: ${AUTOCONF_PORT}
FILES_DIR: ${FILES_DIR}
EOF
}


render_templates() {
    log_info "Render mustache templates..."

    if [ ! -f "${TEMPLATES_DIR}/values.mustache" ]; then
        log_error "Values file not found: ${TEMPLATES_DIR}/values.mustache"
        return 1
    fi

    docker run \
        --name mustache \
        --rm \
        -v ${TEMPLATES_DIR}:/templates:ro \
        --entrypoint /usr/bin/mustache \
        toolbelt/mustache \
        /templates/values.mustache /templates/$1.template > ${FILES_DIR}/$1 || log_error "Failed generate mustache template"
}

main() {
    log_info "Starting setting docker-compose environment"
    ###
    # Step 1
    ###
    MI_DOCKER_DIR_PATH=$(find /mnt -name mi_docker -type d -prune 2>/dev/null)
    COUNT=$(echo "$MI_DOCKER_DIR_PATH" | wc -l)
    if [ "$COUNT" -eq 0 ]; then
        echo "Error: No docker-binaries directory found"
        exit 1
    elif [ "$COUNT" -gt 1 ]; then
        echo "Error: Multiple docker-binaries directories found:"
        echo "$MI_DOCKER_DIR_PATH"
        echo "Please specify which one to use"
        exit 1
    fi
    [ ! -d "${MI_DOCKER_DIR_PATH}" ] && echo "Error: Directory \"/mnt/.../mi_docker\" does not exist." && exit 1
    [ ! -f "/var/run/docker/opa/authz.rego" ] && echo "Error: File /var/run/docker/opa/authz.rego does not exist." && exit 1

    # Configuration variables
    DOCKER_PATH="${MI_DOCKER_DIR_PATH}/docker-binaries"
    SCRIPTS_DIR="${MI_DOCKER_DIR_PATH}/scripts"
    FILES_DIR="${MI_DOCKER_DIR_PATH}/files"
    TEMPLATES_DIR="${MI_DOCKER_DIR_PATH}/templates"
    OPA_POLICY_FILE="/var/run/docker/opa/authz.rego"
    BASE_REPO_URL="https://raw.githubusercontent.com/Viktor3434/router-be7000"
    REPO_URL="${BASE_REPO_URL}/main"

    ###
    # Step 2
    ###
    create_directories ${SCRIPTS_DIR}
    create_directories ${FILES_DIR}
    create_directories ${TEMPLATES_DIR}

    ###
    # Step 3
    ###
    download_file $REPO_URL/files/hosts.txt      $FILES_DIR
    download_file $REPO_URL/files/nginx-pac.conf $FILES_DIR

    download_file $REPO_URL/scripts/change-opa-policy.sh       $SCRIPTS_DIR
    download_file $REPO_URL/scripts/create-alias.sh            $SCRIPTS_DIR
    download_file $REPO_URL/scripts/download-docker-compose.sh $SCRIPTS_DIR

    download_file $REPO_URL/templates/docker-compose.yaml.template $TEMPLATES_DIR
    download_file $REPO_URL/templates/nginx-proxy.pac.template     $TEMPLATES_DIR
    download_file $REPO_URL/templates/privoxy.conf.template        $TEMPLATES_DIR

    ###
    # Step 4
    ###
    run_opa_policy_fix

    ###
    # Step 5
    ###
    run_create_alias ${DOCKER_PATH}

    ###
    # Step 6
    ###
    run_download_docker_compose ${DOCKER_PATH}

    ###
    # Step 7
    ###
    ROUTER_IP=$(ip addr show br-lan | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    HTTP_PROXY_IP_ADDR="${ROUTER_IP}"
    HTTP_PROXY_PORT='8118'
    BYE_SOCS_PORT='8800'
    AUTOCONF_PORT='8888'
    generate_values_mustache

    render_templates docker-compose.yaml
    render_templates nginx-proxy.pac
    render_templates privoxy.conf

    log_success "Setup completed successfully!"
    echo
    log_info "Next steps:"
    log_info "1. Run: cd $FILES_DIR && docker-compose up -d"
    log_info "2. Configure browser to use PAC: http://${ROUTER_IP}:8888/proxy.pac"
    log_info "3. Check logs: docker-compose logs"
    echo
    log_info "Future plans: Implement ByeDPI command optimization"
}

main
