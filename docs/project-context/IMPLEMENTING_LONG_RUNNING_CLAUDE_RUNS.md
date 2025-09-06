Objective

Summarize practical, minimal-risk architectures and recipes to run or resume Claude/Claude Code work that is constrained by a short interactive session limit (~5 hours). This is research-only guidance; no repository code is changed.

Constraints & assumptions

- User stated: Claude Code sessions appear to have a ~5 hour limit. Treat this as a hard per-session time window.
- Goal: run workloads longer than the session limit, or reliably resume multi-hour agentic tasks.
- No repo edits; deliver guidance in this document under `docs/project-context`.
- Reasonable assumptions: standard cloud/Kubernetes tooling available; you can deploy small helper services (MCP server, workflow engine) if desired.

High-level patterns (short)

1) Externalize state via MCP (recommended first-line)
- Description: Run Claude statelessly and keep persistent state/tool endpoints external to the model via a Model Context Protocol (MCP) server. Each LLM call is independent; the MCP server stores conversation state, tool outputs, checkpoints, and event hooks. When Claude's session ends, context lives outside the session and a new session can be resumed by reattaching to the same MCP.
- How this addresses the 5-hour limit: the session lifetime is irrelevant because the context is externalized; you re-open a new session and rehydrate context. Long-running logic lives in the orchestrator (see pattern 2) or the MCP server.
- Pros: minimal cost, simpler to implement, aligns with Anthropic's recommended MCP approach, good for resumability and auditability.
- Cons: requires building or deploying an MCP server (or using an MCP partner), you must design secure, tokenized access and consider rate limits or conversation size.
- Refs: Anthropic MCP docs & partner directories; MCP server partners (commercial & OSS).

2) Durable orchestrator + checkpointing (Temporal / Step Functions / Argo/ etc.)
- Description: Use a workflow engine that supports durable long-running workflows to orchestrate calls to Claude. The orchestrator manages retries, backoffs, durable timers, and stores checkpoints/state. Work is split into steps; when a step needs model inference, orchestrator invokes Claude (stateless call), records outputs, and progresses the workflow.
- How it addresses the 5-hour limit: orchestrator persists workflow state across sessions/runs. The model call is quick compared to orchestrator durability, so workflows can span days/weeks.
- Candidates: Temporal (durable execution, SDKs, good for agentic flows), AWS Step Functions (Standard Workflows up to 1 year + wait-for-callback patterns), Argo Workflows (K8s-native), Airflow (scheduled DAG orchestration for batch semantics).
- Pros: Robust failure semantics, retries, observability, scalable; known production patterns for agents (Temporal blog posts & examples). Step Functions offers serverless managed durability.
- Cons: Operational complexity; Temporal requires infra or Temporal Cloud; Step Functions costs can grow; Argo/Argo CD requires k8s infra.
- Refs: Temporal blog "Durable Execution meets AI" and "Building long-running interactive MCP tools with Temporal"; AWS Step Functions docs (.waitForTaskToken / .sync patterns).

3) Short-lived sessions + periodic rehydration (split-and-resume)
- Description: Break work into shorter tasks that finish well inside 5 hours. Persist progress after each task. A scheduler (CronJob, Celery, RQ, or Cron) starts the next task, reading the last checkpoint and invoking Claude as needed.
- How it addresses the 5-hour limit: no single session exceeds the limit; logic resumes from saved checkpoints.
- Pros: Simple to implement, minimal orchestration stack, fits into existing task queues (Celery, RQ) or Kubernetes CronJobs/Jobs.
- Cons: Work must be easily divisible; introduces latency between chunks; you must design idempotency and atomic checkpoints.
- Refs: Kubernetes Jobs/CronJobs docs (suspend/resume, activeDeadlineSeconds), RQ and Celery docs (job_timeout, scheduling, retries).

4) Callback/Task-Token pattern (event-driven resume)
- Description: Use an orchestrator that can pause and wait for an external event/callback. For example, AWS Step Functions' wait-for-task-token or a Temporal workflow that waits for a signal. The LLM or supporting system issues a task token and the resumed event (external system) signals completion.
- How it addresses the 5-hour limit: long waits are handled by the orchestration layer; LLM calls remain short-lived.
- Pros: Natural fit for user-driven or external-event-driven workflows (human in the loop, external job finish). Clean separation of concerns.
- Cons: Must implement reliable callback wiring and security for tokens.
- Refs: AWS Step Functions Task Token docs, Temporal signals & activities.

Anti-patterns / what to avoid

- Trying to keep an LLM interactive session alive by sleeping/looping in-process for hours. This is fragile (network hiccups, cost, resource locks) and likely to hit provider enforced session limits. Prefer checkpointing/externalization.
- Storing large raw conversation contexts in-memory for resume; instead, store serialized structured checkpoints and minimal prompts.

Concrete recipes (quick)

Recipe A — Minimal: Deploy an MCP server + checkpoint store
- Components: small MCP server (open-source or partner), Postgres or S3 for checkpoints, short cron worker for retries.
- Steps:
  1. Deploy or subscribe to an MCP server (or run a lightweight implementation). Secure it via mTLS / auth tokens.
  2. On each Claude call, push a copy of the conversation and structured checkpoint to the MCP store.
  3. To resume: start a new Claude Code session and instruct the MCP server to rehydrate the conversation state and provide a concise prompt refresher.
- When to use: when you want minimal infra and alignment with Anthropic's recommended MCP pattern.

Recipe B — Durable orchestration (Temporal example)
- Components: Temporal server (or Temporal Cloud), worker service implementing workflow logic, checkpoint store (Temporal's persistent store), Claude API integration as activities.
- Steps:
  1. Model the agentic flow as a Temporal workflow where each decision or model call is an activity.
  2. Implement activities that call Claude (stateless), save outputs, and emit signals/checkpoints.
  3. Use durable timers or signals to wait for external events. Temporal persists state between model calls and restarts.
- When to use: production-grade long-running agentic systems that require robust retry, timeouts, visibility.

Recipe C — Kubernetes jobs + checkpointing (Cloud-native)
- Components: K8s cluster, Jobs/CronJobs, shared object store (S3/PV) or DB for checkpoints.
- Steps:
  1. Break the workload into smaller job units. After each job, write a checkpoint to S3 or DB.
  2. Use CronJobs or a controller to launch the next Job when appropriate. For human-triggered resumes, toggle a Job's `suspend` flag or send an event to the controller.
- When to use: you already run Kubernetes and prefer containerized workloads.

Recipe D — Task queue (Celery/RQ) approach (simple orchestration)
- Components: Celery or RQ, Redis or RabbitMQ broker, DB/S3 for checkpoints.
- Steps:
  1. Split logic into chained tasks. After each Celery/RQ task, record progress to checkpoint store.
  2. For retries/timeouts, use built-in retry/backoff. Worker restarts pick up pending tasks.
- When to use: you have Python infra and prefer simplicity over full durable orchestration.

Security & cost notes

- Secrets: store API keys and tokens in a secrets manager/infisical or sealed secrets. Never log keys. Restrict MCP server access to authorized clients only.
- Cost: durable orchestration (Temporal Cloud or Step Functions) has steady costs; Step Functions Standard pricing and state transitions add up, Temporal Cloud has subscription tiers. K8s + self-hosted Temporal/Argo has infra costs.

Quick decision guide

- Need a small, low-dev-effort solution for resumability → Use MCP server (Recipe A).
- Need production-grade durability, retries, and long time horizons → Use Temporal or Step Functions (Recipe B).
- Already use Kubernetes and want container-native jobs → Use K8s Jobs/CronJobs + checkpoints (Recipe C).
- Want minimal infra and use Python stacks → Use Celery/RQ + checkpointing (Recipe D).

Next steps & checklist for your project

- Choose a pattern above (pick 1) and run a small POC:
  - MCP POC: Deploy or subscribe to an MCP server, implement a small rehydrate flow for a 30–60 minute run and test resuming after a session ends.
  - Temporal POC: Implement a tiny workflow with one activity calling Claude and one timer; test that state persists across worker restarts.
  - K8s POC: Implement a simple Job that writes checkpoint to S3 and a CronJob that uses the checkpoint to resume.
- Evaluate: resilience, security, operational cost, latency, developer productivity.

References & reading (selected from authoritative sources)
- Anthropic / Claude & MCP docs (see Anthropic developer docs and MCP partner directory)
- Temporal blog: "Durable Execution meets AI", "Building long-running interactive MCP tools with Temporal"
- AWS Step Functions docs: Standard Workflows & Task Token (.waitForTaskToken)
- Kubernetes Jobs/CronJobs docs (suspend/resume, activeDeadlineSeconds, podFailurePolicy)
- LangChain & LangGraph blog posts: stateful/long-running agents and LangGraph platform
- Celery / RQ docs: task chaining, scheduling, retries

Requirements coverage

- Research-only, no changes to repository: satisfied (this file is documentation only).
- Summarize online solutions & references: covered in the sections above.
- Provide practical recipes & next steps: included as Recipes A–D and POC checklist.

Short completion note

This delivers a compact, actionable guide placed at `docs/project-context/IMPLEMENTING_LONG_RUNNING_CLAUDE_RUNS.md`.

MCP deep-dive (detailed)

1) What MCP provides and what it does NOT
- MCP (Model Context Protocol) is a lightweight JSON-RPC style protocol that lets an LLM host (Claude or another client) discover and call tools exposed by an MCP server. Tools declare input/output schemas and human-friendly descriptions. MCP makes tool discovery and invocation dynamic and language-driven.
- Important limitation: the MCP specification itself is deliberately thin on durability. MCP servers typically answer RPC calls and return results; the spec does not mandate durable execution, long-running state, or visibility by default. Durability needs to be added by the MCP server implementor or by coupling MCP tools to a durable orchestrator (see Temporal pattern below).

2) MCP server options (OSS & commercial partners)
- Anthropic Partner Directory: many commercial partners expose MCP integrations or hosted solutions (see Anthropic "MCP Integrations" / Partners pages). These partners often provide hosted MCP servers or higher-level platforms that implement discovery, auth, and tool hosting.
- OSS MCP servers & examples:
  - modelcontextprotocol/servers (community repositories): a collection of sample servers and adapters (varies by maintainer; check the modelcontextprotocol GitHub org for maintained server code). Note: some URLs and repos are still early-stage or moved; search GitHub for "mcp server" or "modelcontextprotocol server".
  - Goose / Block's "Goose" example: an MCP host/client example that integrates MCP tools in production-like setups (useful for patterns).
  - Temporal community samples (Aslan11 temporal-durable-mcp weather/invoice samples): demonstrate wrapping MCP tools in durable Temporal Workflows (excellent reference for implementing durability).
- Commercial platforms: some partners in Anthropic's directory (Builder.io, Dust, etc.) may provide hosted tool platforms or integration points; evaluate partner capabilities individually for MCP hosting and durability.

3) Minimal MCP server architecture (for durability and resume)
- Components:
  - MCP API endpoint: accepts MCP discovery/tool calls and returns tool descriptors (name, descriptions, input schema).
  - Tool runtime dispatcher: when a tool is invoked, this component routes the request to either a synchronous handler, a durable workflow, or an async worker.
  - Durable execution layer (optional but recommended): Temporal, Step Functions, or a task queue used to run long-running tools. This layer receives work requests from the dispatcher and returns a workflow handle or execution ID.
  - Checkpoint/State store: Postgres, S3, or other durable store for conversation checkpoints, partial outputs, and artifacts.
  - Auth & token service: issue short-lived tokens, validate callers, and map sessions → identities.
  - Event/Callback bridge: secure callback endpoints or task-token handlers that allow external events to notify workflows (used by Step Functions task token patterns or Temporal signals).

4) Rehydrate & resume contract (practical design)
- When the MCP tool starts long work, the server should:
  1. Create a durable execution (workflow) and return an immediate response containing an execution id / workflow id and optionally a short result summary.
  2. Persist a compact checkpoint representing the tool inputs, the most recent model messages, and the minimal context required to continue later.
  3. Expose a status/query tool (e.g., `tool_status(workflow_id)`) and a signal/patch tool (e.g., `tool_signal(workflow_id, patch)`) so the agent can query and nudge the running work.
- To resume after a session ends:
  - Start a new Claude session and call an MCP rehydrate helper: either `get_status(workflow_id)` to fetch the latest checkpoint and a short natural-language summary, or call `rehydrate(workflow_id)` which returns a compact history and the next prompt fragment. The new session should avoid re-sending full long histories; instead use a brief context primer plus the workflow id for future queries.

5) Security model & best practices
- Issue per-session short-lived tokens scoped to specific MCP actions (discover, call, query, signal). Rotate tokens frequently and log usage.
- Enforce least-privilege: tools that access sensitive systems or personal data should require stricter scopes and review.
- Validate tool input schemas using strong schema validation (zod, JSON Schema) to avoid injections or unexpected structures.
- Protect callback endpoints: task tokens must be unguessable, single-use, and tied to workflow IDs; expire tokens when workflows finish.
- Audit logs: write immutable logs for tool invocations, signals, and workflow state transitions for debugging and compliance.

6) Short code/interaction sketch (pseudocode)
- Tool invocation (MCP server):

  request -> MCP server
  MCP server -> dispatcher
  dispatcher -> start durable workflow (Temporal) with args
  return { workflow_id }

- Agent resume flow (new Claude session):

  new session -> call MCP rehydrate(workflow_id)
  MCP returns { short_summary, recent_checkpoints }
  new session sends concise prompt: "Resume workflow <id>: <short_summary>" and continues.

Best-practices & community writeups (summary)

- Anti-patterns reinforced:
  - Do not try to keep a single interactive session alive via sleep/keep-alive for multi-hour runs.
  - Avoid re-sending entire conversation history to rehydrate; prefer compact checkpoints plus an event id.

- Community patterns:
  - Checkpoint often: write atomically after each significant step so resume is easy.
  - Idempotency: make tool actions idempotent or detect duplicates using unique ids to avoid double-processing after retries.
  - Small prompts on resume: synthesize a short summary of prior conversation state to reduce token usage and accelerate reattachment.
  - Observability: expose status endpoints and integrate logs/traces into your APM so operators can inspect stuck runs.

References and examples (specific)
- Temporal: "Durable MCP: How to give agentic systems superpowers" and Temporal MCP examples (invoice/weather samples on GitHub).
- Anthropic: Developer docs (Claude Code) and MCP partner pages (Anthropic Partners). 
- Samples: Aslan11/temporal-durable-mcp-weather-sample, Aslan11/temporal-invoice-mcp (pattern examples showing MCP <-> Workflow integration).

Next steps (recommended immediate)

- If you want me to finish: I will now collect community writeups and best-practice posts (todo #4), add concise summaries and links, and then mark todo #3 and #5 completed. Tell me to proceed and I'll continue.
Community writeups & best-practices (concise)

- LangChain / LangGraph: production agent infra
  - LangChain blog and LangGraph platform posts emphasize runtime features for stateful, long-running agents: orchestration primitives, observability, and intent/state management. LangGraph is positioned to deploy/manage durable agents with tooling to manage message content, tool invocation, and rehydration patterns.
  - Useful for teams already on LangChain/LangGraph — they provide managed runtimes and patterns for compact resumability and stateful agents.

- Towards Data Science & community posts
  - Practical guides on checkpointing, context engineering, and LLM-orchestrated workflows. Articles recommend compact checkpoints, idempotent operations, and separating decision & tool layers to simplify resuming work.
  - Example posts: "Using LangGraph and MCP Servers to Create My Own Voice Assistant" (TDS), "Tool Masking: The Layer MCP Forgot" (TDS) — good conceptual reads for prompt masking and minimizing tokens on resume.

- Dev/Medium/DEV community
  - Developer writeups and tutorials often show small POCs: local MCP server experiments, LangGraph experiments, and Celery/RQ-driven chunked workflows. These are practical starting points and include sample code and lessons learned.

Practical checklist (from community best-practices)

1. Design compact checkpoints: store only the salient facts needed to resume (IDs, last decisions, short summary) rather than full message dumps.
2. Make actions idempotent: track unique ids per tool invocation so retries don't double-run side effects.
3. Provide status and query endpoints in your MCP server so a new session can ask "what's the current state" without rehydrating full logs.
4. Use durable orchestrators for long waits and human-in-the-loop flows (Temporal / Step Functions) and MCP + durable workflows for the best of both worlds.
5. Implement strict auth for MCP endpoints and rotate tokens; store secrets in a secured store.

Finishing note

I marked todo #3 completed and set todo #4 in-progress; I'll finish collecting and summarizing a few more specific articles and examples if you'd like me to continue (then I'll finalize todo #5 and produce a short decision table). Proceed? 

Curated links & samples (high-value)

- Anthropic — Claude Code Quickstart (CLI) — https://docs.anthropic.com/en/docs/claude-code/quickstart — Claude Code CLI, resume commands, and MCP connector mention.
- Anthropic — Tool use with Claude (overview) — https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/overview — Client vs server tool flows, tool_use shapes, and pricing/note on tool usage.
- Model Context Protocol — Introduction & Spec — https://modelcontextprotocol.io/introduction and https://modelcontextprotocol.io/specification/draft/basic — MCP JSON-RPC shapes, auth guidance, and SDK pointers.
- Model Context Protocol — Servers registry (community) — https://github.com/modelcontextprotocol/servers — catalog of reference MCP servers and adapters (useful for quick POCs).
- Temporal blog — Durable MCP: How to give agentic systems superpowers — https://temporal.io/blog/durable-mcp-how-to-give-agentic-systems-superpowers — argues for "tools as workflows" and shows patterns for durable MCP tools.
- Temporal blog — Building long-running interactive MCP tools with Temporal — https://temporal.io/blog/building-long-running-interactive-mcp-tools-temporal — hands-on examples and patterns for signals/queries.
- Aslan11 — temporal-invoice-mcp (GitHub) — https://github.com/Aslan11/temporal-invoice-mcp — Invoice sample: start workflow via MCP tool, interact via signals, query status; run instructions included.
- Aslan11 — temporal-durable-mcp-weather-sample (GitHub) — https://github.com/Aslan11/temporal-durable-mcp-weather-sample — Weather sample demonstrating MCP <-> Temporal durable tool wiring.
- LangChain blog — Building LangGraph — https://blog.langchain.com/building-langgraph/ — LangGraph design and rationale for checkpointing and agent orchestration.
- LangChain blog — LangGraph Platform GA — https://blog.langchain.com/langgraph-platform-ga/ — Platform features for long-running agents (checkpointing, Studio, persistence).
- Towards Data Science — Using LangGraph and MCP Servers to Create My Own Voice Assistant — https://towardsdatascience.com/using-langgraph-and-mcp-servers-to-create-my-own-voice-assistant — practical LangGraph + FastMCP POC with checkpointer examples.
- Towards Data Science — Tool Masking: The Layer MCP Forgot — https://towardsdatascience.com/tool-masking-the-layer-mcp-forgot-66b1aa1f8f6e — concept of exposing a minimal tool surface to reduce token bloat and improve reliability.
- AWS Step Functions — Task Token pattern (.waitForTaskToken) — https://docs.aws.amazon.com/step-functions/latest/dg/connectors-task-token.html — pattern for external callbacks to long-running workflows.
- Kubernetes — Jobs, CronJobs, activeDeadlineSeconds & suspend/resume docs — https://kubernetes.io/docs/concepts/workloads/controllers/job/ and https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/ — patterns for batch checkpointing and resume.
- Celery — Task routing, chaining, retries — https://docs.celeryproject.org/en/stable/ — practical for simple task-queue chunking approaches.

Decision matrix (concise)

Approach | Durability | Complexity | Cost & Ops | Observability | Max practical run
-|-|-|-|-|-
MCP-only (externalize state) | Medium (depends on server) | Low | Low | Medium | Indefinite (if server persists state)
Temporal (MCP + workflows) | High (durable) | High | Medium-High | High | Indefinite (Temporal persists state)
LangGraph / Platform | High (platform-managed) | Medium | Medium (platform) | High (Studio) | Indefinite (checkpointing)
K8s Jobs / CronJobs | Medium | Medium | Depends on infra | Medium | Bounded by Job timeouts (but can chain)
Celery / RQ | Low-Medium | Low | Low | Low-Medium | Bounded by worker TTLs and broker retention

POC checklist (3-step, small experiment)

1) Quick MCP POC (30–60 min)
  - Deploy a lightweight MCP server (or run a reference server locally).
  - Implement a single MCP tool that stores a checkpoint in Postgres/S3 and returns workflow_id.
  - Start a Claude Code session, invoke the tool, then end the session and re-open a new session to call `rehydrate(workflow_id)` and resume.

2) Temporal POC (local)
  - Start Temporal dev server (temporal server start-dev). Run a simple workflow that calls Claude as an activity and persists outputs.
  - From the MCP server, implement a tool that starts the workflow and returns workflow_id. Test signaling the workflow from a separate tool.
  - Kill the Temporal worker, restart it, and confirm workflow state persisted and resumed.

3) LangGraph / Agent runtime POC (optional)
  - Use LangGraph examples to implement a checkpointer for short runs and a resume flow. Validate the platform's Studio for visibility and checkpointing behavior.

Requirements coverage map

- Research-only deliverable placed under `docs/project-context`: Done.
- Collected MCP deep-dive and durable orchestration patterns: Done.
- Added curated links & sample repos: Done.
- Created decision matrix & POC checklist: Done.

Completion summary

I added a curated links section, a concise decision matrix, and a 3-step POC checklist to `docs/project-context/IMPLEMENTING_LONG_RUNNING_CLAUDE_RUNS.md`. I validated the file was updated. Next recommended action: pick one POC (MCP-only or Temporal) and I can produce step-by-step runbook commands and minimal worker/tool code to bootstrap the experiment.

