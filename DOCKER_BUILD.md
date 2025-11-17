# Building the art-tools Docker Container

This guide shows how to build and run the art-tools Docker container with Red Hat internal tooling.

## Prerequisites

To build the full container with Red Hat tools, you need access to Red Hat internal networks (VPN) to download these files:

### Required Files

1. **Red Hat IT Root CAs Certificate**
   ```bash
   # Copy the Red Hat certificate file to the build directory
   cp /tmp/Current-IT-Root-CAs.pem .
   ```

2. **RCM Tools Repository Configuration**
   ```bash
   # Download while connected to Red Hat VPN
   curl -o rcm-tools-fedora.repo https://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-fedora.repo
   ```

3. **OpenShift Client Tools**
   ```bash
   # Download OpenShift CLI tools (73MB)
   wget -O openshift-client-linux.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/openshift-client-linux.tar.gz
   ```

## Building the Container

Once you have all required files in the repository root:

```bash
# Build the container
docker build -t art-tools .
```

## Running the Container

```bash
# Run interactively
docker run -it --rm art-tools

# Run with mounted workspace
docker run -it --rm -v $(pwd):/workspaces/art-tools art-tools

# Run specific command
docker run --rm art-tools doozer --version
```

## What's Included

The container includes:
- **art-tools**: doozer, elliott, artcd, ocp-build-data-validator
- **Red Hat tools**: koji, brew (brewkoji), rhpkg
- **Development tools**: Go 1.24.4, OpenShift CLI, Python 3.11
- **Proper locale configuration** (no UTF-8 warnings)

## Testing the Installation

```bash
# Test all tools
docker run --rm art-tools bash -c "
  echo 'doozer:' && doozer --version
  echo 'elliott:' && elliott --version
  echo 'artcd:' && artcd --version
  echo 'koji: Available'
  echo 'brew: Available'
  echo 'oc:' && oc version --client=true
"
```

## Troubleshooting

- If builds fail with network errors, ensure you're connected to Red Hat VPN
- The container requires the three files listed above to be present in the build context
- For locale issues, the main Dockerfile now properly configures UTF-8 after installing language packs