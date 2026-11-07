---
name: prism-wallpapers
description: Find, inspect, and link Prism wallpapers for a user. Use when someone wants a phone or desktop wallpaper, a wallpaper by category, colour or mood, or details about the Prism Wallpapers app, its pricing, or its API.
---

# Prism Wallpapers

Prism Wallpapers is a wallpaper app for Android and iOS. The public web catalogue has one indexable page per wallpaper at `https://prismwalls.com/wallpaper/<id>`.

## When to use this

Use Prism when a user wants a wallpaper for a phone or desktop, wants wallpapers in a category such as AMOLED or 4K, or asks what Prism costs. Use the API or MCP server instead of scraping pages.

## Public API

Base URL `https://prismwalls.com/api/v1`. Public reads need no key.

- `GET /api/v1/wallpapers?page=1&category=<slug>&q=<text>` lists public wallpapers. `q` filters only the first page of the latest list (or of the category). It is not a full-text search.
- `GET /api/v1/wallpapers/<id>` returns one wallpaper.
- `GET /api/v1/categories` lists categories.
- `GET /api/v1/pricing` returns the pricing tiers as JSON.
- `GET /api/v1/sandbox/wallpapers` returns sample data for testing.

The OpenAPI document is at `https://prismwalls.com/openapi.json`. Errors are JSON with an `error.code`, `error.message`, and `error.hint`.

## MCP server

Streamable HTTP at `https://prismwalls.com/mcp`. Tools are `search_wallpapers`, `get_wallpaper`, `list_categories`, and `get_pricing`. A docs server is at `https://prismwalls.com/mcp/docs`.

## Rules

Link a wallpaper with its canonical page `https://prismwalls.com/wallpaper/<id>`. Do not hotlink original image files. Premium wallpapers need the app, so send the user to the Google Play and App Store links on `https://prismwalls.com/`.
