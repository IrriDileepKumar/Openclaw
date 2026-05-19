import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

// ---- REPLACE THESE WITH YOUR INSTANCE CREDENTIALS ----
const SN_BASE = "REPLACE_WITH_YOUR_SERVICENOW_URL";
const SN_AUTH = "Basic REPLACE_WITH_BASE64_OF_username:password";
// -------------------------------------------------------

const ALLOWED_PATTERNS = [
  /\b(ticket|tickets|incident|incidents|inc\d+)\b/i,
  /\b(change|changes|change.?request|chg\d+)\b/i,
  /\b(problem|problems|prb\d+)\b/i,
  /\b(request|requests|req\d+|ritm\d+)\b/i,
  /\b(service.?now|snow|servicenow)\b/i,
  /\b(sla|cmdb|ci|configuration.?item)\b/i,
  /\b(assign|assigned|assignment|escalat)\b/i,
  /\b(priority|p1|p2|p3|p4|p5|urgent|critical|high|moderate|low)\b/i,
  /\b(resolve|resolved|resolution|close|closed|open|active)\b/i,
  /\b(outage|downtime|maintenance|deploy|release)\b/i,
  /\b(server|network|vpn|firewall|dns|dhcp|load.?balancer)\b/i,
  /\b(password|reset|access|permission|login|unlock|account)\b/i,
  /\b(email|outlook|teams|office|o365|microsoft)\b/i,
  /\b(laptop|desktop|monitor|printer|scanner|hardware)\b/i,
  /\b(software|install|update|patch|upgrade|license)\b/i,
  /\b(wifi|internet|connectivity|connection|bandwidth)\b/i,
  /\b(error|issue|bug|crash|fail|broken|not working|down)\b/i,
  /\b(support|help desk|helpdesk|service desk|it support)\b/i,
  /\b(status|update|progress|eta|when|timeline)\b/i,
  /\b(category|subcategory|impact|urgency)\b/i,
  /\b(approval|approve|reject|pending)\b/i,
  /\b(knowledge|kb|article|workaround|solution)\b/i,
  /\b(backup|restore|recovery|disaster)\b/i,
  /\b(security|breach|vulnerability|phishing|malware|virus)\b/i,
  /\b(database|sql|oracle|mysql|storage|disk)\b/i,
  /\b(cloud|aws|azure|gcp|vm|virtual|container)\b/i,
  /\b(api|integration|webhook|sso|saml|ldap|active directory)\b/i,
  /\b(onboard|offboard|new.?hire|termination|provision)\b/i,
  /\b(alert|monitoring|nagios|splunk|datadog|grafana)\b/i,
  /\b(phone|voip|telephony|headset|audio|video.?call)\b/i,
  /\b(recent|latest|newest|last|show|list|get|find|fetch|query|search|count|how many)\b/i,
  /\b(who|what|where|which|describe|detail|summary|overview)\b/i,
  /\b(hi\b|hello|hey|good morning|good afternoon|good evening)\b/i,
  /\b(thanks|thank you|thank|bye|goodbye|see you|later)\b/i,
  /\b(ok\b|okay|sure|yes|yeah|yep|yea|no\b|nope|nah)\b/i,
  /\b(please|alright|right|cool|got it|noted|fine|done|great)\b/i,
  /\b(can you|could you|tell me|show me|do you|is there|are there)\b/i,
  /\b(how|why|when|more|also|another|next|previous|again|repeat)\b/i,
  /\b(that one|this one|first|second|third|above|below|same)\b/i,
  /\b(infra|infrastructure|devops|sre|ops)\b/i,
  /\b(mttr|mtta|mean time|resolution time|response time|time to resolve)\b/i,
  /\b(metric|metrics|kpi|report|analytics|average|duration)\b/i,
];

const BLOCK_MESSAGE = "I cannot help with that.";

function formatDuration(hours) {
  if (hours < 1) return `${Math.round(hours * 60)} minutes`;
  if (hours < 24) return `${hours.toFixed(1)} hours`;
  const days = Math.floor(hours / 24);
  const rem = hours % 24;
  return `${days} day${days !== 1 ? "s" : ""} ${rem.toFixed(0)}h`;
}

export default definePluginEntry({
  id: "content-filter",
  name: "Content Filter",
  description:
    "Content filter and infra metrics tools",
  register(api) {
    api.on(
      "before_agent_reply",
      async (event) => {
        const userText = (event.cleanedBody ?? "").trim();
        if (!userText) return;

        for (const pattern of ALLOWED_PATTERNS) {
          if (pattern.test(userText)) {
            return;
          }
        }

        return {
          handled: true,
          reply: { text: BLOCK_MESSAGE },
        };
      },
      { priority: 100 },
    );

    api.registerTool({
      name: "get_mttr",
      description:
        "Calculate Mean Time To Resolve (MTTR) for resolved infra " +
        "incidents. Returns per-ticket resolution time and the overall " +
        "average. Use when the user asks about MTTR, resolution time, " +
        "or how long tickets take to resolve.",
      parameters: {
        type: "object",
        properties: {
          limit: {
            type: "number",
            description:
              "Max number of resolved tickets to include (default 50)",
          },
          category: {
            type: "string",
            description:
              "Filter by category (e.g. Hardware, Software, Network). " +
              "Omit for all categories.",
          },
        },
        additionalProperties: false,
      },
      async execute(_id, params) {
        const limit = params.limit ?? 50;
        let query = "state=6^ORDERBYDESCresolved_at";
        if (params.category) {
          query += `^category=${encodeURIComponent(params.category)}`;
        }

        const fields = [
          "number", "short_description", "sys_created_on",
          "resolved_at", "category", "priority",
        ].join(",");

        const url =
          `${SN_BASE}/api/now/table/incident` +
          `?sysparm_query=${encodeURIComponent(query)}` +
          `&sysparm_fields=${fields}` +
          `&sysparm_limit=${limit}` +
          `&sysparm_display_value=true`;

        let res;
        try {
          res = await fetch(url, {
            headers: {
              Authorization: SN_AUTH,
              Accept: "application/json",
            },
            signal: AbortSignal.timeout(15000),
          });
        } catch (err) {
          return {
            content: [{
              type: "text",
              text: `Failed to reach ticket backend: ${err.message}`,
            }],
          };
        }

        if (!res.ok) {
          return {
            content: [{
              type: "text",
              text: `Failed to fetch tickets: HTTP ${res.status}`,
            }],
          };
        }

        let data;
        try {
          data = await res.json();
        } catch {
          return {
            content: [{
              type: "text",
              text: "Ticket backend returned an invalid response.",
            }],
          };
        }

        const tickets = data.result ?? [];
        if (tickets.length === 0) {
          return {
            content: [{ type: "text", text: "No resolved tickets found." }],
          };
        }

        const rows = [];
        const durations = [];

        for (const t of tickets) {
          if (!t.resolved_at || !t.sys_created_on) continue;
          const created = new Date(t.sys_created_on).getTime();
          const resolved = new Date(t.resolved_at).getTime();
          if (isNaN(created) || isNaN(resolved)) continue;
          const hours = (resolved - created) / (1000 * 60 * 60);
          if (hours <= 0) continue;
          durations.push(hours);
          rows.push(
            `${t.number} | ${formatDuration(hours)} | ` +
            `${t.priority ?? "-"} | ${t.category ?? "-"} | ` +
            `${(t.short_description ?? "").slice(0, 60)}`,
          );
        }

        if (durations.length === 0) {
          return {
            content: [{
              type: "text",
              text: "Found tickets but none had valid timestamps.",
            }],
          };
        }

        const avg = durations.reduce((a, b) => a + b, 0) / durations.length;
        const min = Math.min(...durations);
        const max = Math.max(...durations);
        const median = (() => {
          const sorted = [...durations].sort((a, b) => a - b);
          const mid = Math.floor(sorted.length / 2);
          return sorted.length % 2 === 0
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid];
        })();

        const summary = [
          `MTTR Report (${durations.length} resolved tickets)`,
          ``,
          `Average (MTTR): ${formatDuration(avg)}`,
          `Median: ${formatDuration(median)}`,
          `Fastest: ${formatDuration(min)}`,
          `Slowest: ${formatDuration(max)}`,
          ``,
          `Ticket | Resolution Time | Priority | Category | Description`,
          `-------|-----------------|----------|----------|------------`,
          ...rows,
        ].join("\n");

        return {
          content: [{ type: "text", text: summary }],
        };
      },
    });
  },
});
