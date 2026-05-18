#!/bin/bash
#
# OpenClaw setup script
# Run this on a fresh Linux instance to get OpenClaw running
# with Metrum AI (Kimi K2.6), ServiceNow, and WhatsApp.
#

set -e

echo "=== OpenClaw Setup ==="
echo ""

# ---- 1. Node.js (need v22.12+) ----

NODE_VERSION=$(node --version 2>/dev/null || echo "none")
echo "Current Node.js: $NODE_VERSION"

if ! command -v node &>/dev/null || [ "$(node -e 'console.log(process.versions.node.split(".")[0] >= 22 ? "ok" : "no")')" != "ok" ]; then
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
echo "Installing ServiceNow MCP server..."
npm install -g happy-platform-mcp

# ---- 5. Copy config files ----

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "Copying config files..."
mkdir -p ~/.openclaw/agents/main/agent

if [ ! -f ~/.openclaw/openclaw.json ]; then
    cp "$SCRIPT_DIR/openclaw.json" ~/.openclaw/openclaw.json
    chmod 600 ~/.openclaw/openclaw.json
    echo "  Copied openclaw.json"
else
    echo "  openclaw.json already exists -- skipping (check manually)"
fi

if [ ! -f ~/.openclaw/agents/main/agent/auth-profiles.json ]; then
    cp "$SCRIPT_DIR/auth-profiles.json" ~/.openclaw/agents/main/agent/auth-profiles.json
    chmod 600 ~/.openclaw/agents/main/agent/auth-profiles.json
    echo "  Copied auth-profiles.json"
else
    echo "  auth-profiles.json already exists -- skipping (check manually)"
fi

# ---- 6. Remind about placeholders ----

echo ""
echo "=== IMPORTANT: Edit these files before starting ==="
echo ""
echo "1. ~/.openclaw/agents/main/agent/auth-profiles.json"
echo "   Replace: REPLACE_WITH_YOUR_METRUM_API_KEY"
echo "   With:    your Metrum API key (sk-bf-...)"
echo ""
echo "2. ~/.openclaw/openclaw.json"
echo "   Replace: REPLACE_WITH_NEW_GATEWAY_TOKEN"
echo "   With:    any random hex string (or run 'openclaw doctor' to generate one)"
echo ""
echo "   Replace: REPLACE_WITH_YOUR_SERVICENOW_URL"
echo "   With:    https://YOUR-INSTANCE.service-now.com"
echo ""
echo "   Replace: REPLACE_WITH_YOUR_USERNAME"
echo "   With:    your ServiceNow username"
echo ""
echo "   Replace: REPLACE_WITH_YOUR_PASSWORD"
echo "   With:    your ServiceNow password"
echo ""

# ---- 7. Next steps ----

echo "=== Next Steps ==="
echo ""
echo "1. Edit the config files above with real values"
echo "2. Run:  openclaw doctor"
echo "3. Run:  openclaw gateway start"
echo "4. Link WhatsApp:"
echo "   openclaw plugins install clawhub:@openclaw/whatsapp"
echo "   openclaw channels login --channel whatsapp"
echo "   (zoom out terminal to see QR code, scan with phone)"
echo "5. Chat:  openclaw"
echo "   Type 'talk to agent' then ask about ServiceNow tickets"
echo ""
echo "=== Done ==="
