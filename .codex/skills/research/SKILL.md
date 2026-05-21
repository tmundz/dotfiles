---
name: research
description: >
  Comprehensive multi-agent research system with quick, standard, extensive, and deep investigation modes.
  Launches parallel research agents (Claude, Gemini, Grok, Perplexity) for multi-perspective results with
  mandatory URL verification. Use for research, investigation, find information, analyze content, extract
  insights, web scraping, YouTube extraction, AI trends analysis, deep investigation, fact-finding, or
  any research task requiring multiple sources and synthesis.
---

# Research Skill

Multi-agent research system supporting four modes of increasing depth and thoroughness.

## Research Modes

| Mode | Agents | Time | When to Use |
|------|--------|------|-------------|
| Quick | 1 | ~15s | Simple factual lookup, single question |
| Standard | 2 | ~30s | Most research requests (default) |
| Extensive | 9 | ~90s | Deep multi-perspective coverage |
| Deep Investigation | 12+ iterative | Minutes | Full landscape mapping + entity profiling |

**Default:** "research X" → Standard mode (2 agents). Escalate only when user asks for depth.

## URL Verification (MANDATORY)

**NEVER include any URL without verification.** Research agents hallucinate URLs.

Read `references/UrlVerificationProtocol.md` before delivering results with URLs.
A single broken link is a catastrophic failure.

## Workflow Reference

All workflows are in `references/`:

| Workflow | File |
|----------|------|
| Quick research (1 agent) | `references/QuickResearch.md` |
| Standard research (2 agents) | `references/StandardResearch.md` |
| Extensive research (9 agents) | `references/ExtensiveResearch.md` |
| Deep investigation (iterative vault) | `references/DeepInvestigation.md` |
| AI trends analysis | `references/AnalyzeAiTrends.md` |
| Content enhancement | `references/Enhance.md` |
| Alpha extraction | `references/ExtractAlpha.md` |
| Knowledge extraction from docs | `references/ExtractKnowledge.md` |
| Interview-style research | `references/InterviewResearch.md` |
| YouTube video extraction | `references/YoutubeExtraction.md` |
| Web scraping research | `references/WebScraping.md` |
| URL content retrieval | `references/Retrieve.md` |

## Researcher Types

- **ClaudeResearcher** — academic depth, analytical rigor
- **GeminiResearcher** — cross-domain breadth, multiple perspectives
- **GrokResearcher** — contrarian analysis, social/current events
- **PerplexityResearcher** — current web, recent news, social media
- **CodexResearcher** — technical depth, developer-focused topics

## Output Format

All research results include:
1. Executive Summary (3-5 bullets)
2. Key Findings by theme (with confidence levels)
3. Sources (verified URLs only)
4. Conflicts and uncertainties flagged explicitly
