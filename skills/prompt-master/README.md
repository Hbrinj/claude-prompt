# Prompt Master

A Claude skill that writes the perfect prompt for any AI tool. Zero tokens or credits wasted. Full context and memory retention.

Works with: Claude, ChatGPT, Gemini, o1/o3, Cursor, Claude Code, GitHub Copilot, Windsurf, Bolt, v0, Lovable, Devin, Perplexity, Midjourney, DALL-E, Stable Diffusion, Sora, Runway, ElevenLabs, Zapier, Make, and any AI tool you throw at it.

---

## Installation

### Claude.ai (browser)

1. Download this repo as a ZIP
2. Or Copy the full contents of SKILL.md
3. Go to **claude.ai → Sidebar → Customize → Upload into Custom Skill**


### Recommended (clone directly into Claude Code skills directory)

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/nidhinjs/prompt-master.git ~/.claude/skills/prompt-master
```

### Manual install / update (only the skill file)

If you already have this repo cloned (or downloaded `SKILL.md`), copy the skill file into Claude Code's skills directory:

```bash
mkdir -p ~/.claude/skills/prompt-master
cp SKILL.md ~/.claude/skills/prompt-master/
```


---

## Usage

In Claude, invoke the skill naturally:

```
Write me a prompt for Cursor to refactor my auth module
```

```
I need a prompt for Claude Code to build a REST API — ask me what you need to know
```

```
Generate a Midjourney prompt for a cyberpunk city at night
```

Or explicitly invoke it:

```
/prompt-master

I want to ask Claude Code to build a todo app with React and Supabase
```

---

## The Problem This Solves

Every AI user burns credits the same way:

> Write vague prompt → get wrong output → re-prompt → get closer → re-prompt again → finally get what you wanted on attempt 4

That's 3 wasted API calls. Multiply by 50 prompts a day. Credits and time wasted stacks quickly.

### Key Insight

> "The best prompt is not the longest; it's the one where every word is load-bearing."

Most "prompt generators" make prompts longer. This skill makes them sharper.

---

## How It Works

Prompt Master runs a structured pipeline on every request:

1. **Detects the target tool** — identifies which AI system the prompt is for and applies tool-specific optimizations
2. **Extracts 9 dimensions of intent** — task, input, output, constraints, context, audience, memory, success criteria, examples
3. **Asks targeted clarifying questions** — max 3 questions if critical info is missing, never more
4. **Selects the right framework** — chooses from 9 prompt frameworks based on task type
5. **Applies advanced techniques** — layers in CoT, few-shot, XML tags, memory blocks, grounding anchors as needed
6. **Runs a token efficiency audit** — strips every word that doesn't change the output
7. **Delivers the prompt** — clean copyable block with target tool, framework used, token estimate, and strategy note

---

## Works With Any AI Tool

Prompt Master includes specific profiles for 18+ tools. For anything not on the list, it uses a **Universal Fingerprint** — 4 questions that let it write a quality prompt for any AI system it has never seen before.

| Tool | Category | What Prompt Master Fixes |
|------|----------|--------------------------|
| **Claude** | Reasoning LLM | Removes padding, adds XML structure, specifies length |
| **ChatGPT / GPT-4o** | Reasoning LLM | Strong role assignment, explicit format, numeric constraints |
| **Gemini 2.x** | Reasoning LLM | Grounding anchors, citation rules, format locks |
| **o1 / o3** | Thinking LLM | Short clean instructions only — never adds CoT (they think internally) |
| **Local models (Llama, Mistral)** | Open-weight LLM | Shorter prompts, simpler structure, no complex nesting |
| **Claude Code** | Agentic AI | Stop conditions, file scope, checkpoint output |
| **Cursor / Windsurf** | IDE AI | File path, function name, do-not-touch list |
| **GitHub Copilot** | Autocomplete AI | Exact function contract as docstring |
| **Bolt / v0 / Lovable** | Full-stack generator | Stack spec, version, what NOT to scaffold |
| **Devin / SWE-agent** | Autonomous agent | Starting state, target state, stop conditions |
| **Perplexity / SearchGPT** | Search AI | Mode spec: search vs analyze vs compare |
| **Midjourney** | Image AI | Comma-separated descriptors, parameters, negative prompts |
| **DALL-E 3** | Image AI | Prose description, text exclusion instruction |
| **Stable Diffusion** | Image AI | Weight syntax `(word:1.3)`, CFG guidance, mandatory negative prompt |
| **Sora / Runway** | Video AI | Camera movement, duration, cut style |
| **ElevenLabs** | Voice AI | Emotion, pacing, emphasis, speech rate |
| **Zapier / Make** | Workflow automation | Trigger app + event, action app + field mapping |

---

## 9 Prompt Frameworks — Auto-Selected

Prompt Master picks the right architecture for every task automatically.

| Framework | Best For |
|-----------|----------|
| **RTF** (Role, Task, Format) | Fast one-shot tasks |
| **CO-STAR** (Context, Objective, Style, Tone, Audience, Response) | Professional documents, reports, business writing |
| **RISEN** (Role, Instructions, Steps, End Goal, Narrowing) | Complex multi-step projects |
| **CRISPE** (Capacity, Role, Insight, Statement, Personality, Experiment) | Creative work, brand voice, iterative content |
| **Chain of Thought** | Math, logic, debugging, multi-step analysis |
| **Few-Shot** | Consistent structured output, pattern replication |
| **File-Scope Template** | Cursor, Windsurf, Copilot — any code editing AI |
| **ReAct + Stop Conditions** | Claude Code, Devin, AutoGPT — any autonomous agent |
| **Visual Descriptor** | Midjourney, DALL-E, Stable Diffusion, Sora |

---

## 10 Advanced Techniques Applied Automatically

| Technique | What It Does |
|-----------|-------------|
| **Role Activation** | Assigns a specific expert identity to calibrate depth and vocabulary |
| **Chain of Thought** | Forces step-by-step reasoning for logic and analysis tasks |
| **Few-Shot Injection** | Adds 2–5 examples when format consistency matters more than instructions |
| **XML Structural Tags** | Wraps sections in XML for Claude-based tools that parse it reliably |
| **Response Prefilling** | Starts the AI's response with the first characters to lock in format |
| **Prompt Chaining** | Splits complex tasks into sequential focused prompts |
| **Grounding Anchors** | Adds anti-hallucination rules for factual and citation tasks |
| **Output Scaffolding** | Provides the skeleton for long structured outputs |
| **Negative Constraints** | Adds precise do-not-do rules without triggering reverse-psychology effects |
| **Self-Check Instruction** | Asks the AI to verify its own output before finishing |

---

## 35 Credit-Killing Patterns Detected (with Before/After Examples)

### Task Patterns

| # | Pattern | Before | After |
|---|---------|--------|-------|
| 1 | **Vague task verb** | "help me with my code" | "Refactor `getUserData()` to use async/await and handle null returns" |
| 2 | **Two tasks in one prompt** | "explain AND rewrite this function" | Split: explain first, rewrite second |
| 3 | **No success criteria** | "make it better" | "Done when function passes existing unit tests and handles null input" |
| 4 | **Over-permissive agent** | "do whatever it takes" | Explicit allowed + forbidden actions list |
| 5 | **Emotional task description** | "it's totally broken, fix everything" | "Throws uncaught TypeError on line 43 when `user` is null" |
| 6 | **Build-the-whole-thing** | "build my entire app" | Break into Prompt 1 (scaffold), Prompt 2 (feature), Prompt 3 (polish) |
| 7 | **Implicit reference** | "now add the other thing we discussed" | Always restate the full task — never reference "the thing we discussed" |

### Context Patterns

| # | Pattern | Before | After |
|---|---------|--------|-------|
| 8 | **Assumed prior knowledge** | "continue where we left off" | Include Memory Block with all prior decisions |
| 9 | **No project context** | "write a cover letter" | "PM role at B2B fintech, 2yr SWE experience, shipped 3 features as tech lead" |
| 10 | **Forgotten stack** | New prompt contradicts prior tech choice | Always include Memory Block |
| 11 | **Hallucination invite** | "what do experts say about X?" | "Cite only sources you are certain of. If uncertain, say so." |
| 12 | **Undefined audience** | "write something for users" | "Non-technical B2B buyers, no coding knowledge, decision-maker level" |
| 13 | **No mention of prior failures** | (blank) | "I already tried X and it failed because Y. Do not suggest X." |

### Format Patterns

| # | Pattern | Before | After |
|---|---------|--------|-------|
| 14 | **Missing output format** | "explain this concept" | "3 bullet points, each under 20 words, one-sentence summary at top" |
| 15 | **Implicit length** | "write a summary" | "Write a summary in exactly 3 sentences" |
| 16 | **No role assignment** | (blank) | "You are a senior backend engineer specializing in Node.js and PostgreSQL" |
| 17 | **Vague aesthetic adjectives** | "make it look professional" | "Monochrome palette, 16px base font, 24px line height, no decorative elements" |
| 18 | **No negative prompts (image AI)** | "a portrait of a woman" | Add: "no watermark, no blur, no extra fingers, no distortion, no text" |
| 19 | **Prose prompt for Midjourney** | Full descriptive sentence | "subject, style, mood, lighting, --ar 16:9 --v 6" |

### Scope Patterns

| # | Pattern | Before | After |
|---|---------|--------|-------|
| 20 | **No scope boundary** | "fix my app" | "Fix only login form validation in `src/auth.js`. Touch nothing else." |
| 21 | **No stack constraints** | "build a React component" | "React 18, TypeScript strict, no external libraries, Tailwind only" |
| 22 | **No stop condition for agents** | "build the whole feature" | Explicit stop conditions + ✅ checkpoint after each step |
| 23 | **No file path for IDE AI** | "update the login function" | "Update `handleLogin()` in `src/pages/Login.tsx` only" |
| 24 | **Wrong template for tool** | GPT-style prose used in Cursor | Adapted to File-Scope Template with path + scope |
| 25 | **Pasting entire codebase** | Full repo context every prompt | Scoped to relevant function and file only |

### Reasoning Patterns

| # | Pattern | Before | After |
|---|---------|--------|-------|
| 26 | **No CoT for logic task** | "which approach is better?" | "Think through both approaches step by step before recommending" |
| 27 | **Adding CoT to reasoning models** | "think step by step" sent to o1/o3 | Removed — reasoning models think internally, CoT instructions degrade output |
| 28 | **No self-check on complex output** | (nothing) | "Before finishing, verify output against the constraints above" |
| 29 | **Expecting inter-session memory** | "you already know my project" | Always re-provide the Memory Block |
| 30 | **Contradicting prior decisions** | New prompt ignores earlier architecture | Memory Block with all established facts |

### Agentic Patterns

| # | Pattern | Before | After |
|---|---------|--------|-------|
| 31 | **No starting state** | "build me a REST API" | "Empty Node.js project, Express installed, `src/app.js` exists" |
| 32 | **No target state** | "add authentication" | "`/src/middleware/auth.js` with JWT verify. `POST /login` and `POST /register` in `/src/routes/auth.js`" |
| 33 | **Silent agent** | No progress output | "After each step output: ✅ [what was completed]" |
| 34 | **Unlocked filesystem** | No file restrictions | "Only edit files inside `src/`. Do not touch `package.json`, `.env`, or any config file." |
| 35 | **No human review trigger** | Agent decides everything | "Stop and ask before: deleting any file, adding any dependency, or touching the database schema" |

---

## Memory Block System

When your conversation has history, Prompt Master automatically extracts prior decisions and prepends a Memory Block so the AI never contradicts earlier work:

```
## Memory (Carry Forward from Previous Context)
- Stack: React 18 + TypeScript + Supabase
- Auth uses JWT stored in httpOnly cookies, not localStorage
- Component naming convention: PascalCase, no default exports
- Design system: Tailwind only, no custom CSS files
- Architecture: no Redux, context API only
```

This solves the #1 cause of wasted re-prompts in long sessions.

---

## References

- [Anthropic Prompt Engineering Guide](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview) — Primary source for Claude-specific patterns
- [OpenAI Prompt Engineering Guide](https://platform.openai.com/docs/guides/prompt-engineering) — GPT-4o best practices
- [Cursor Documentation](https://docs.cursor.com) — IDE-specific context patterns
- [Midjourney Prompt Reference](https://docs.midjourney.com/docs/prompts) — Image AI parameter guide

---

## Version History

- **1.3.0** — Rebuilt around PAC2026 positional structure (30/55/15). Silent routing replaces user-facing framework selection. Reference folders introduced
- **1.2.0** — Restructured for attention architecture. Removed fabrication-prone techniques (ToT, GoT, USC, prompt chaining). Templates and patterns moved to references folder.
- **1.1.0** — Expanded tool coverage, added memory block system, 35 patterns
- **1.0.0** — Initial release

---

## License

MIT
