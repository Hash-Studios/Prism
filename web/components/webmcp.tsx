"use client";

import { useEffect } from "react";

type ToolDefinition = {
  name: string;
  description: string;
  inputSchema: { type: "object"; properties: Record<string, { type: string; description?: string }>; required?: string[] };
  execute: (input: Record<string, unknown>) => Promise<{ content: Array<{ type: "text"; text: string }> }>;
};

type ModelContext = {
  registerTool: (tool: ToolDefinition) => void;
  unregisterTool: (name: string) => void;
};

async function fetchAsText(path: string) {
  const response = await fetch(path);
  const body = await response.text();
  return { content: [{ type: "text" as const, text: body }] };
}

export function WebMcp() {
  useEffect(() => {
    const context = (document as Document & { modelContext?: ModelContext }).modelContext
      ?? (navigator as Navigator & { modelContext?: ModelContext }).modelContext;
    if (!context) return;

    context.registerTool({
      name: "search_wallpapers",
      description: "Search Prism Wallpapers by query or visual subject.",
      inputSchema: { type: "object", properties: { q: { type: "string", description: "Search query" } }, required: ["q"] },
      execute: ({ q }) => fetchAsText(`/api/v1/wallpapers?q=${encodeURIComponent(String(q ?? ""))}`),
    });
    context.registerTool({
      name: "get_pricing",
      description: "Get current Prism Wallpapers pricing information.",
      inputSchema: { type: "object", properties: {} },
      execute: () => fetchAsText("/api/v1/pricing"),
    });
    context.registerTool({
      name: "list_categories",
      description: "List available Prism Wallpapers categories.",
      inputSchema: { type: "object", properties: {} },
      execute: () => fetchAsText("/api/v1/categories"),
    });
    return () => {
      for (const name of ["search_wallpapers", "get_pricing", "list_categories"]) {
        context.unregisterTool(name);
      }
    };
  }, []);

  return null;
}
