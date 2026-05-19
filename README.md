# Infra Agents Assistant - OpenClaw Setup

WhatsApp bot that lets users query infra incidents and tickets using natural language.
Built on OpenClaw with Metrum AI (Kimi K2.6) as the LLM and ServiceNow as the ticket backend.


## What you get after setup

- A WhatsApp bot branded as "Infra Agents Assistant"
- Users message the bot on WhatsApp and ask about incidents, tickets, changes
- Bot queries ServiceNow behind the scenes (never mentions ServiceNow to the user)
- Content filter blocks off-topic messages (songs, jokes, etc.) before they hit the LLM
- MTTR (Mean Time To Resolve) tool calculates resolution metrics from resolved tickets
- All ServiceNow write operations are blocked (read-only)
- Each WhatsApp number gets its own isolated session
- Owner phone number gets admin commands (like `/new` to reset sessions)


## Prerequisites

Before you start, make sure you have:

1. A Linux machine (Ubuntu/Debian tested, any distro with Node.js works)
2. A Metrum AI API key (Anthropic-compatible, starts with `sk-bf-...`)
3. A ServiceNow instance URL, username, and password
4. A phone with WhatsApp (the bot will link to this number as a paired device)


## Folder structure

```
openclaw-setup/
  README.md                          -- this file
  setup.sh                           -- automated installer
  openclaw.json                      -- main config template
  auth-profiles.json                 -- API key template
  workspace/
    AGENTS.md                        -- agent role, allowed/blocked topics
    IDENTITY.md                      -- bot persona
    TOOLS.md                         -- system prompt + ticket API config
  plugins/
    content-filter/
      index.js                       -- allowlist filter + MTTR tool code
      package.json                   -- plugin package config
      openclaw.plugin.json           -- plugin manifest
```


## Step-by-step setup

### Step 1: Install Node.js 22+

OpenClaw requires Node.js version 22.12 or higher.

```bash
node --version
```

If it shows v22+ you can skip this. Otherwise install it:

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

Verify:

```bash
node --version
# should show v22.x.x
```


### Step 2: Set up npm global prefix

This avoids needing sudo for global npm installs:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```


### Step 3: Clone this repo and run setup

```bash
git clone <your-repo-url> openclaw-setup
cd openclaw-setup
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Install OpenClaw globally
- Install the ServiceNow MCP server (happy-platform-mcp)
- Copy all config files to `~/.openclaw/`
- Auto-detect and patch the MCP server path for your machine
- Print a list of all placeholders you need to fill in


### Step 4: Fill in your credentials

You need to edit 4 files. Replace every `REPLACE_WITH_*` placeholder with real values.

**File 1: ~/.openclaw/agents/main/agent/auth-profiles.json**

Open it:

```bash
nano ~/.openclaw/agents/main/agent/auth-profiles.json
```

Replace:
- `REPLACE_WITH_YOUR_METRUM_API_KEY` with your Metrum API key (e.g. `sk-bf-abc123...`)

---

**File 2: ~/.openclaw/openclaw.json**

Open it:

```bash
nano ~/.openclaw/openclaw.json
```

Replace these 5 placeholders:

| Placeholder | What to put |
|---|---|
| `REPLACE_WITH_NEW_GATEWAY_TOKEN` | Any random string. You can generate one: `openssl rand -hex 24` |
| `REPLACE_WITH_YOUR_SERVICENOW_URL` | Your ServiceNow instance URL, e.g. `https://dev203926.service-now.com` |
| `REPLACE_WITH_YOUR_USERNAME` | ServiceNow username, e.g. `admin` |
| `REPLACE_WITH_YOUR_PASSWORD` | ServiceNow password |
| `REPLACE_WITH_OWNER_PHONE_NUMBER` | Your phone number with country code, e.g. `+919392616864` |

---

**File 3: ~/.openclaw/plugins/content-filter/index.js**

Open it:

```bash
nano ~/.openclaw/plugins/content-filter/index.js
```

At the top of the file, replace:
- `REPLACE_WITH_YOUR_SERVICENOW_URL` with same URL as above (e.g. `https://dev203926.service-now.com`)
- `REPLACE_WITH_BASE64_OF_username:password` with the base64-encoded credentials

Generate the base64 value like this:

```bash
echo -n 'admin:YourPasswordHere' | base64
```

It will output something like `YWRtaW46WW91clBhc3N3b3JkSGVyZQ==`.
Put that after `Basic ` in the file, so it looks like:

```
const SN_AUTH = "Basic YWRtaW46WW91clBhc3N3b3JkSGVyZQ==";
```

---

**File 4: ~/.openclaw/workspace/TOOLS.md**

Open it:

```bash
nano ~/.openclaw/workspace/TOOLS.md
```

Scroll to the "Ticket Backend" section and replace:
- `REPLACE_WITH_YOUR_SERVICENOW_URL` with your instance URL
- `REPLACE_WITH_YOUR_USERNAME` with your username
- `REPLACE_WITH_YOUR_PASSWORD` with your password
- `REPLACE_WITH_BASE64_OF_username:password` with the same base64 value from step 3

Also update the example API URLs in that section to use your actual instance URL.


### Step 5: Run OpenClaw doctor

This validates your config and fixes common issues:

```bash
openclaw doctor
```

If it asks about generating a gateway token and you already set one, skip it.
If it reports issues, fix them before proceeding.


### Step 6: Start the gateway

```bash
openclaw gateway start
```

The gateway runs in the background as a systemd service. Verify it is running:

```bash
openclaw gateway status
```

If you see errors, check the logs:

```bash
journalctl --user -u openclaw-gateway.service --since "5 min ago"
```


### Step 7: Install WhatsApp plugin

```bash
openclaw plugins install clawhub:@openclaw/whatsapp
```


### Step 8: Link WhatsApp

```bash
openclaw channels login --channel whatsapp
```

A QR code will appear in your terminal. If it is too big to scan:
- Press **Ctrl + minus** to zoom out the terminal
- Or open a full-screen terminal (not inside an IDE)

On your phone:
1. Open WhatsApp
2. Go to Settings > Linked Devices > Link a Device
3. Scan the QR code

After scanning, the terminal should confirm the link.


### Step 9: Test it

**Test in TUI (terminal):**

```bash
openclaw
```

Type `talk to agent` to switch from the setup helper to the main agent.
Then ask: "show me open incidents"

**Test on WhatsApp:**

Send a message to the linked WhatsApp number from another phone.
Try these:
- "hi" -- should get the greeting
- "show me recent incidents" -- should query tickets
- "get the mttr" -- should calculate MTTR from resolved tickets
- "sing a song" -- should get blocked with "I cannot help with that."


### Step 10: Verify everything works

Checklist:
- [ ] Bot responds to "hi" with: "Hi! I am the Infra Agents Assistant. How can I help you with your tickets or incidents?"
- [ ] Bot can list incidents when asked
- [ ] Bot never mentions "ServiceNow" in replies
- [ ] Bot blocks off-topic requests with "I cannot help with that."
- [ ] MTTR tool works when user asks about resolution times
- [ ] Different phone numbers get separate sessions
- [ ] Owner phone number can run `/new` to reset sessions


## How it all works

### Architecture

```
User (WhatsApp) --> OpenClaw Gateway --> Content Filter Plugin
                                             |
                                   (blocked) |  (allowed)
                                     v       v
                               "I cannot   Metrum AI (Kimi K2.6)
                                help."         |
                                          Uses tools:
                                          - ServiceNow MCP (read tickets)
                                          - get_mttr (calculate metrics)
                                               |
                                          Reply to user
```

### openclaw.json -- what each section does

- **models.providers.anthropic** -- points to Metrum AI API (not real Anthropic).
  The baseUrl is `https://llm-api.metrum.ai/anthropic` and the api type is
  `anthropic-messages`. Do NOT add `/v1/messages` to the URL.

- **tools.profile: "coding"** -- this enables both MCP tools and plugin tools.
  Do NOT change to "messaging" as that disables MCP tools.

- **tools.deny** -- blocks all ServiceNow write operations. The bot is read-only.
  It can query tickets but cannot create, update, close, assign, or resolve anything.

- **plugins.entries.content-filter** -- enables the custom plugin.
  `hooks.allowConversationAccess: true` lets the plugin read incoming messages.

- **channels.whatsapp.direct["*"].systemPrompt** -- the system prompt sent to the
  LLM for every WhatsApp conversation. This enforces branding rules, greeting format,
  blocked topics, read-only behavior, and tells the model to use the `get_mttr` tool.

- **session.dmScope: "per-channel-peer"** -- each WhatsApp number gets its own
  isolated session. Messages from one user do not leak into another user's conversation.

- **commands.ownerAllowFrom** -- only this phone number can run admin commands
  like `/new` (reset session). Other users can only chat.

- **mcp.servers.servicenow** -- the ServiceNow MCP server config. Uses the absolute
  path to `node` and the absolute path to the `stdio-server.js` file. The setup script
  patches these paths automatically for your machine. Using `npx` instead of absolute
  paths will NOT work in the systemd service context.

### Content filter plugin

Located at `~/.openclaw/plugins/content-filter/`.

**Allowlist filter (before_agent_reply hook):**
Runs before the LLM processes the message. Checks the user message against a list
of allowed regex patterns (infra keywords, conversational words, greetings, etc.).
If no pattern matches, the bot replies "I cannot help with that." without calling
the LLM at all. This saves tokens and enforces the infra-only scope.

To add new allowed words/phrases, edit `ALLOWED_PATTERNS` in `index.js` and restart
the gateway.

**get_mttr tool:**
A deterministic MTTR calculator registered as a plugin tool. When the LLM gets a
question about MTTR or resolution times, it calls this tool. The tool:
1. Queries ServiceNow for resolved incidents (state=6)
2. Calculates the time difference between created and resolved timestamps
3. Computes average, median, min, max
4. Returns a formatted report

The LLM then presents this report to the user.

### Workspace files

- **AGENTS.md** -- defines the bot's role (Infra Agents Assistant), lists allowed
  topics (incidents, tickets, changes, MTTR) and blocked topics (songs, jokes,
  coding, personal advice, etc.), and sets security rules.

- **IDENTITY.md** -- sets the bot persona: name, vibe (professional, concise),
  no emojis. Short file, but OpenClaw reads it to shape the bot's personality.

- **TOOLS.md** -- the main system instructions file. Contains:
  - Branding rules (never mention ServiceNow)
  - Greeting template
  - Blocked request handling
  - Security rules (never reveal credentials)
  - ServiceNow API credentials and example API calls for `web_fetch`


## Common operations after setup

**Restart the gateway (after config changes):**

```bash
openclaw gateway restart
```

**Clear all sessions (if bot has stale context):**

```bash
rm -rf ~/.openclaw/sessions/*
openclaw gateway restart
```

**Check gateway logs:**

```bash
journalctl --user -u openclaw-gateway.service --since "10 min ago"
```

**Check MCP server logs specifically:**

```bash
journalctl --user -u openclaw-gateway.service --since "10 min ago" | grep mcp
```

**Re-link WhatsApp (if disconnected):**

```bash
openclaw channels login --channel whatsapp
```

**Update ServiceNow credentials:**

If your ServiceNow password changes, update it in these 3 files:
1. `~/.openclaw/openclaw.json` (mcp.servers.servicenow.env section)
2. `~/.openclaw/plugins/content-filter/index.js` (SN_BASE and SN_AUTH at top)
3. `~/.openclaw/workspace/TOOLS.md` (Ticket Backend section)

Then restart: `openclaw gateway restart`


## Troubleshooting

**"openclaw: command not found"**
Your PATH does not include the npm global bin. Run:
```bash
export PATH="$HOME/.npm-global/bin:$PATH"
```
Add it to `~/.bashrc` to make it permanent.

**"Node.js v22.12+ is required"**
Install Node 22+. See Step 1 above.

**Gateway won't start / "missing gateway.mode"**
Make sure `gateway.mode` is set to `"local"` in `~/.openclaw/openclaw.json`.

**"API keys: Anthropic not found" during doctor**
This is a superficial check. If `auth-profiles.json` has the key, it works at runtime.
You can ignore this warning.

**WhatsApp QR code too big to scan**
Zoom out with Ctrl + minus, or use a full-screen terminal outside of an IDE.

**MCP server fails to start / "Connection closed"**
The `command` in `mcp.servers.servicenow` must be the absolute path to your `node`
binary (e.g. `/usr/bin/node` or `~/.nvm/.../node`), not `npx`. And the `args` must
point to the actual `stdio-server.js` file. `setup.sh` patches this automatically,
but if you installed Node differently, check the paths:
```bash
which node
find ~/.npm-global -name "stdio-server.js" -path "*/happy-platform-mcp/*"
```

**Bot responds "I cannot help with that." to normal questions**
The content filter allowlist might be too strict. Edit
`~/.openclaw/plugins/content-filter/index.js`, add your patterns to
`ALLOWED_PATTERNS`, and restart: `openclaw gateway restart`.

**Bot mentions ServiceNow in replies**
Old session cache might have stale context. Clear it:
```bash
rm -rf ~/.openclaw/sessions/*
openclaw gateway restart
```

**MTTR tool not working / LLM says it cannot calculate MTTR**
- Make sure `tools.profile` is `"coding"` in openclaw.json (not `"messaging"`)
- Make sure the ServiceNow credentials in `index.js` are correct
- Check that the ServiceNow instance is reachable from the machine
- Start a new session (`/new` on WhatsApp or restart the TUI)

**Agent asks for ServiceNow credentials**
You are probably talking to Crestodian (the setup helper). Type `talk to agent`
in the TUI to switch to the main agent.

**"Something went wrong" errors on WhatsApp**
Usually means the LLM API (Metrum) is rate-limited or down. Check:
```bash
journalctl --user -u openclaw-gateway.service --since "5 min ago" | grep -i error
```
Wait a minute and try again, or check your Metrum API key and quota.

**Tickets not sorted correctly / only showing closed tickets**
The MCP tool's `order_by` parameter uses `sysparm_order_by` which does not sort
correctly in ServiceNow. The sorting must go inside the `query` parameter using
ServiceNow encoded query syntax (`ORDERBYDESCopened_at`), not `sysparm_order_by`.
We patched `~/.npm-global/lib/node_modules/happy-platform-mcp/src/mcp-server-consolidated.js`
so `SN-List-Incidents`, `SN-List-ChangeRequests`, and `SN-List-Problems` always
append `ORDERBYDESCopened_at` to the query when no sort is specified. If you
reinstall `happy-platform-mcp` via npm, you will lose this patch and need to
reapply it.

**LLM uses web_fetch instead of MCP tools (401 errors)**
If TOOLS.md contains explicit API URLs with credentials, the LLM will try to use
`web_fetch` to call ServiceNow directly instead of using the MCP tools. The
`web_fetch` tool does not pass auth headers, so it gets 401 Unauthorized errors.
Fix: remove all raw API URLs and credentials from `~/.openclaw/workspace/TOOLS.md`.
Instead, tell the LLM to use the servicenow MCP tools which handle auth automatically.

**Different users getting different/inconsistent results**
The LLM does not always follow prompt instructions consistently. Do not rely on
prompt instructions alone for critical behavior like sorting. Patch the MCP tool
code directly (see "Tickets not sorted correctly" above) so the correct behavior
is enforced at the tool level regardless of what the LLM passes.

**content-filter plugin "not found" warning**
The `openclaw doctor --fix` command removes the content-filter entry from
`plugins.entries` in `openclaw.json` because it is a local plugin, not an
installed one. After running doctor --fix:
1. Re-add the content-filter entry to `plugins.entries` in `~/.openclaw/openclaw.json`:
   ```json
   "content-filter": {
     "enabled": true,
     "hooks": { "allowConversationAccess": true }
   }
   ```
2. Make sure the plugin files are in `~/.openclaw/extensions/content-filter/`
   (not just `~/.openclaw/plugins/content-filter/`). OpenClaw loads plugins
   from the `extensions` directory.

**Gateway stops at night / after closing SSH (NUC or local machines)**
Two common causes:
1. Machine goes to sleep/hibernate (power management). Disable sleep:
   ```bash
   sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
   ```
2. Systemd user services die when the user session ends. Enable linger so
   services survive after logout:
   ```bash
   sudo loginctl enable-linger $USER
   ```
   On AWS EC2, always run `sudo loginctl enable-linger ubuntu` after setup so the
   gateway stays alive even when you disconnect from SSH.
