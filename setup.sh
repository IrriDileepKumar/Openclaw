#!/bin/bash
#
# OpenClaw setup script
# Sets up the Infra Agents Assistant with:
#   - Metrum AI (Kimi K2.6) as the LLM
#   - ServiceNow MCP for ticket queries
#   - WhatsApp channel for messaging
#   - Content filter plugin (allowlist + MTTR tool)
#   - Workspace files (AGENTS.md, IDENTITY.md, TOOLS.md)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Infra Agents Assistant - OpenClaw Setup ==="
echo ""

# ---- 1. Node.js (need v22.12+) ----

NODE_VERSION=$(node --version 2>/dev/null || echo "none")
echo "Current Node.js: $NODE_VERSION"

if ! command -v node &>/dev/null || \
   [ "$(node -e 'console.log(process.versions.node.split(".")[0] >= 22 ? "ok" : "no")')" != "ok" ]; then
    echo ""
    echo "Node.js 22+ is required. Install it first:"
    echo "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
    echo "  sudo apt-get install -y nodejs"
    echo ""
    echo "Or use nvm:"
    echo "  nvm install 22 && nvm use 22 && nvm alias default 22"
    exit 1
fi

# ---- 2. npm global prefix (avoid sudo) ----

echo ""
echo "Setting up npm global prefix..."
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global

if ! grep -q '.npm-global/bin' ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.npm-global/bin:$PATH"

# ---- 3. Install OpenClaw ----

echo ""
echo "Installing OpenClaw..."
npm install -g openclaw

# ---- 4. Install ServiceNow MCP server ----

echo ""
echo "Installing ServiceNow MCP server (happy-platform-mcp)..."
npm install -g happy-platform-mcp

# ---- 5. Find the MCP server path and patch openclaw.json ----

MCP_PATH=$(node -e "try { \
  const p = require.resolve('happy-platform-mcp/src/stdio-server.js'); \
  console.log(p); \
} catch { \
  const path = require('path'); \
  console.log(path.join(process.env.HOME, '.npm-global/lib/node_modules/happy-platform-mcp/src/stdio-server.js')); \
}")

echo "MCP server path: $MCP_PATH"

# ---- 6. Copy config files ----

echo ""
echo "Copying config files..."
mkdir -p ~/.openclaw/agents/main/agent
mkdir -p ~/.openclaw/workspace
mkdir -p ~/.openclaw/plugins/content-filter

if [ ! -f ~/.openclaw/openclaw.json ]; then
    cp "$SCRIPT_DIR/openclaw.json" ~/.openclaw/openclaw.json
    chmod 600 ~/.openclaw/openclaw.json

    # Patch the MCP server path to match this machine
    NODE_BIN=$(which node)
    sed -i "s|REPLACE_WITH_PATH_TO_happy-platform-mcp/src/stdio-server.js|$MCP_PATH|g" \
        ~/.openclaw/openclaw.json
    sed -i "s|/usr/bin/node|$NODE_BIN|g" \
        ~/.openclaw/openclaw.json

    echo "  Copied openclaw.json (MCP path patched)"
else
    echo "  openclaw.json already exists -- skipping (check manually)"
fi

if [ ! -f ~/.openclaw/agents/main/agent/auth-profiles.json ]; then
    cp "$SCRIPT_DIR/auth-profiles.json" \
       ~/.openclaw/agents/main/agent/auth-profiles.json
    chmod 600 ~/.openclaw/agents/main/agent/auth-profiles.json
    echo "  Copied auth-profiles.json"
else
    echo "  auth-profiles.json already exists -- skipping"
fi

# ---- 7. Copy workspace files ----

echo ""
echo "Copying workspace files..."

for f in AGENTS.md IDENTITY.md TOOLS.md; do
    if [ ! -f ~/.openclaw/workspace/$f ]; then
        cp "$SCRIPT_DIR/workspace/$f" ~/.openclaw/workspace/$f
        echo "  Copied $f"
    else
        echo "  $f already exists -- skipping"
    fi
done

# ---- 8. Copy content-filter plugin ----

echo ""
echo "Copying content-filter plugin..."

for f in index.js package.json openclaw.plugin.json; do
    cp "$SCRIPT_DIR/plugins/content-filter/$f" \
       ~/.openclaw/plugins/content-filter/$f
    echo "  Copied plugins/content-filter/$f"
done

# ---- 9. List all placeholders to replace ----

echo ""
echo "============================================="
echo "  SETUP DONE -- NOW EDIT THESE PLACEHOLDERS"
echo "============================================="
echo ""
echo "1. ~/.openclaw/agents/main/agent/auth-profiles.json"
echo "   -> REPLACE_WITH_YOUR_METRUM_API_KEY"
echo "   With your Metrum API key (sk-bf-...)"
echo ""
echo "2. ~/.openclaw/openclaw.json"
echo "   -> REPLACE_WITH_NEW_GATEWAY_TOKEN"
echo "      Any random hex string (or run 'openclaw doctor')"
echo "   -> REPLACE_WITH_YOUR_SERVICENOW_URL"
echo "      e.g. https://dev203926.service-now.com"
echo "   -> REPLACE_WITH_YOUR_USERNAME"
echo "      ServiceNow username (e.g. admin)"
echo "   -> REPLACE_WITH_YOUR_PASSWORD"
echo "      ServiceNow password"
echo "   -> REPLACE_WITH_OWNER_PHONE_NUMBER"
echo "      Your WhatsApp number with country code (e.g. +919392616864)"
echo ""
echo "3. ~/.openclaw/plugins/content-filter/index.js"
echo "   -> REPLACE_WITH_YOUR_SERVICENOW_URL (SN_BASE)"
echo "   -> REPLACE_WITH_BASE64_OF_username:password (SN_AUTH)"
echo "      Generate: echo -n 'admin:yourpassword' | base64"
echo ""
echo "4. ~/.openclaw/workspace/TOOLS.md"
echo "   -> Same ServiceNow URL, username, password, base64 auth"
echo ""
echo "============================================="
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. Edit the files above with real values"
echo "  2. openclaw doctor"
echo "  3. openclaw gateway start"
echo "  4. openclaw plugins install clawhub:@openclaw/whatsapp"
echo "  5. openclaw channels login --channel whatsapp"
echo "     (zoom out terminal to see QR, scan with phone)"
echo "  6. openclaw   # to test in TUI"
echo ""
echo "=== Done ==="
