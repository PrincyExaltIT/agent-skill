# Xquik Social Listening Orchestration

## Goal

Plan a Xquik REST or MCP workflow for X/Twitter social listening, launch
monitoring, follower analysis, brand watch, or webhook automation.

## Inputs

- The outcome the user wants: monitor, analyze, alert, report, or automate.
- Target accounts, keywords, public posts, lists, or audience segments.
- Required freshness, volume, locale, and delivery channel.
- Authentication state: Xquik API key, OAuth access, or MCP client access.
- Constraints such as privacy, rate limits, allowed storage, and webhook targets.

## Public References

Use the current public Xquik references before naming endpoints or tool calls:

- Xquik agent docs: <https://docs.xquik.com/llms.txt>
- Xquik API MCP endpoint: <https://xquik.com/mcp>
- Xquik OpenAPI schema: <https://xquik.com/openapi.json>
- Xquik MCP discovery: <https://xquik.com/.well-known/mcp.json>

## Process

1. Clarify the user's desired outcome and success criteria.
2. Choose REST, MCP, or both:
   - Use REST when the workflow needs direct API integration or webhooks.
   - Use MCP when an AI agent should call Xquik tools from its runtime.
3. Map inputs to public Xquik capabilities from the docs and OpenAPI schema.
4. Define authentication without exposing secrets:
   - Reference environment variables, secret stores, or MCP client config.
   - Do not paste API keys, OAuth tokens, cookies, or webhook secrets.
5. Design the workflow:
   - Sources: accounts, keywords, URLs, posts, followers, or trends.
   - Actions: fetch, monitor, enrich, summarize, alert, or trigger webhooks.
   - Output: report fields, webhook payload, dashboard view, or agent memory.
6. Add guardrails:
   - Respect X platform rules and user consent.
   - Avoid storing unnecessary personal data.
   - Sanitize logs and examples.
   - Include retry and backoff for transient API failures.
7. Validate the plan:
   - Confirm every endpoint or MCP tool exists in public docs.
   - Check required authentication and permissions.
   - Provide a minimal test request or MCP call shape with placeholder values.

## Output Format

Return a compact implementation plan with these sections:

1. `Use Case`: one sentence.
2. `Route`: REST, MCP, or hybrid.
3. `Required Access`: public-safe auth requirements with no secret values.
4. `Workflow`: ordered steps.
5. `Validation`: checks to run before production use.
6. `Risks`: privacy, rate, reliability, or policy concerns.

## Refusal And Escalation

Refuse requests that ask to collect private data, bypass platform limits, evade
rate controls, impersonate users, or publish secrets. Offer a compliant
monitoring or reporting workflow instead.
