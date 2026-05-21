---
name: scraping
description: >
  Web scraping via progressive escalation (WebFetch, curl, Playwright, Bright Data proxy) and social
  media platform scraping via Apify actors. Use for scraping, Bright Data, proxy scraping, crawling,
  bot detection bypass, CAPTCHA bypass, JavaScript-heavy sites, Instagram scraping, LinkedIn scraping,
  TikTok scraping, YouTube scraping, Facebook scraping, Google Maps data, Amazon product scraping,
  Twitter/X scraping, or any web data extraction task that resists simple HTTP requests.
---

# Scraping

Web scraping using progressive escalation and platform-specific actors.

## Routing

| Task | Method | Reference |
|------|--------|-----------|
| Scrape a URL | 4-tier progressive escalation | `references/four-tier-scrape.md` |
| Crawl an entire site | Light or Full site crawl | `references/crawl.md` |
| Social media (Instagram, LinkedIn, TikTok, YouTube, Facebook, Twitter) | Apify actors | `references/apify.md` |
| Google Maps / Amazon | Apify actors | `references/apify.md` |

## 4-Tier Escalation (for single URLs)

Escalate through tiers until content is retrieved:

1. **Tier 1** — WebFetch (fastest, no overhead)
2. **Tier 2** — curl with Chrome browser headers (bypasses basic bot detection)
3. **Tier 3** — Playwright browser automation (JavaScript rendering, dynamic content)
4. **Tier 4** — Bright Data MCP (`mcp__Brightdata__scrape_as_markdown`, residential proxies)

Full methodology: `references/four-tier-scrape.md`
Site crawling: `references/crawl.md`

## Apify Social Media Actors

Requires `APIFY_TOKEN` environment variable from `console.apify.com/account/integrations`.

| Platform | Capabilities |
|----------|-------------|
| Instagram | Profiles, posts, hashtags, comments |
| LinkedIn | Profiles, jobs, posts |
| TikTok | Profiles, videos, hashtags |
| YouTube | Channels, videos, comments, search |
| Facebook | Posts, groups, comments |
| Google Maps | Business search, place details, reviews |
| Amazon | Products, pricing, reviews |

Full Apify integration guide: `references/apify-integration.md`
Actor reference: `references/apify.md`

## Requirements

- **Bright Data:** Bright Data MCP configured with valid credentials (for Tier 4)
- **Apify:** `APIFY_TOKEN` in environment
- **Playwright:** Playwright MCP or local browser (for Tier 3)
