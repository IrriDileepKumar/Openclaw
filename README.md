# OpenClaw Setup Guide

OpenClaw with Metrum AI (Kimi K2.6), ServiceNow integration, and WhatsApp channel.


## What this sets up

- OpenClaw AI agent using Kimi K2.6 model via Metrum API (Anthropic-compatible)
- ServiceNow MCP server for querying tickets (incidents, changes, requests)
- WhatsApp channel so anyone can chat with the bot via WhatsApp


## Prerequisites

- Linux machine (Ubuntu/Debian tested)
- Node.js 22.12+ (`node --version` to check)
- Metrum API key (Anthropic-compatible, starts with `sk-bf-...`)
- ServiceNow instance URL + username + password
- A WhatsApp number to link (the bot responds on this number)


## Files in this folder

```
openclaw-setup/
  README.md              -- this file
  setup.sh               -- automated setup script
  openclaw.json          -- main config (copy to ~/.openclaw/openclaw.json)
  auth-profiles.json     -- API key store (copy to ~/.openclaw/agents/main/agent/auth-profiles.json)
```


## Quick setup (automated)

```bash
# 1. Run the setup script
./setup.sh

# 2. Edit config files with your real credentials (see placeholders below)

# 3. Run doctor to validate
openclaw doctor

# 4. Start the gateway
openclaw gateway start

# 5. Install and link WhatsApp
openclaw plugins install clawhub:@openclaw/whatsapp
openclaw channels login --channel whatsapp
# Zoom out terminal (Ctrl + minus) to see QR code, scan with phone

# 6. Start chatting
openclaw
# Type "talk to agent" then ask anything
```


## Manual setup (step by step)

### 1. Install Node.js 22+

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

Or with nvm:

```bash
nvm install 22
nvm use 22
nvm alias default 22
```

### 2. Set up npm global prefix (avoids sudo for global installs)

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Install OpenClaw and ServiceNow MCP server

```bash
npm install -g openclaw
npm install -g happy-platform-mcp
```

### 4. Copy config files

```bash
mkdir -p ~/.openclaw/agents/main/agent

cp openclaw.json ~/.openclaw/openclaw.json
cp auth-profiles.json ~/.openclaw/agents/main/agent/auth-profiles.json

chmod 600 ~/.openclaw/openclaw.json
chmod 600 ~/.openclaw/agents/main/agent/auth-profiles.json
```

### 5. Edit config files -- replace placeholders

**~/.openclaw/agents/main/agent/auth-profiles.json**

Replace `REPLACE_WITH_YOUR_METRUM_API_KEY` with your actual Metrum API key.

**~/.openclaw/openclaw.json**

Replace these placeholders:

| Placeholder                          | Replace with                                   |
|--------------------------------------|-------------------------------------------------|
| REPLACE_WITH_NEW_GATEWAY_TOKEN       | Any random hex string, or let `openclaw doctor` generate one |
| REPLACE_WITH_YOUR_SERVICENOW_URL     | e.g. `https://dev277927.service-now.com`        |
| REPLACE_WITH_YOUR_USERNAME           | ServiceNow username, e.g. `admin`               |
| REPLACE_WITH_YOUR_PASSWORD           | ServiceNow password                             |

### 6. Run doctor and start gateway

```bash
openclaw doctor        # validates config, fixes issues
openclaw gateway start # starts the background gateway service
```

### 7. Install and link WhatsApp

```bash
openclaw plugins install clawhub:@openclaw/whatsapp
openclaw channels login --channel whatsapp
```

A QR code appears in the terminal. If it is too big:
- Press Ctrl + minus to zoom out
- Or use a full-screen external terminal (not inside an IDE)

Scan the QR with your phone: WhatsApp > Settings > Linked Devices > Link a Device.

### 8. Start chatting

```bash
openclaw
```

Type `talk to agent` to switch from the setup helper (Crestodian) to the main agent.
Then ask things like "show me open incidents" and it will query ServiceNow.

Anyone who messages the linked WhatsApp number will get replies from the bot.


## Config reference

### openclaw.json key sections

- `models.providers.anthropic.baseUrl` -- Metrum API endpoint (do NOT add /v1/messages)
- `models.providers.anthropic.api` -- must be `anthropic-messages` for Metrum
- `tools.profile` -- set to `coding` to enable MCP tools
- `gateway.mode` -- must be `local` (gateway won't start without this)
- `channels.whatsapp.dmPolicy` -- `open` (anyone), `allowlist` (specific numbers), or `pairing` (approve first)
- `channels.whatsapp.allowFrom` -- `["*"]` for open, or `["+91XXXXXXXXXX"]` for specific numbers
- `mcp.servers.servicenow` -- ServiceNow MCP server config with credentials

### auth-profiles.json

Stores API keys. The `anthropic:default` profile is used automatically when the model provider is `anthropic`.


## Troubleshooting

**"openclaw: command not found"**
Run: `export PATH="$HOME/.npm-global/bin:$PATH"` or add it to ~/.bashrc.

**"Node.js v22.12+ is required"**
Install Node 22+. Check with `node --version`.

**"Gateway start blocked: missing gateway.mode"**
Make sure `gateway.mode` is set to `"local"` in openclaw.json.

**"API keys: Anthropic not found"**
The env var check is superficial. If auth-profiles.json has the key, it works at runtime.

**WhatsApp QR code too big**
Zoom out with Ctrl + minus, or use a full-screen terminal outside of an IDE.

**ServiceNow MCP tools not showing up**
- Make sure `tools.profile` is set to `"coding"` in openclaw.json
- Start a NEW session after config changes (Ctrl+C, then `openclaw` again)
- Check logs: `journalctl --user -u openclaw-gateway.service --since "5 min ago" | grep mcp`

**Agent asks for ServiceNow credentials even though MCP is configured**
You are probably in Crestodian (setup helper). Type `talk to agent` to switch to the main agent.
