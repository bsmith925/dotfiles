// Recover when the local model writes a tool call inside its thinking.
//
// Swift 1.5 (Qwen3.8) sometimes emits `<tool_call><function=…>` inside an
// unclosed thinking block. The server then reports the whole reply as
// reasoning: no text, no tool call, and the turn ends silently (seen twice
// in ten minutes on 2026-10-09).
//
// 1. message_end: if the stalled reply's thinking holds a complete call, turn
//    it into a real tool call. Pi edits the finalized message in place before
//    it looks for tool calls, so the call runs as if it had been made properly.
// 2. agent_end: if the call was incomplete, send a follow-up quoting it. The
//    drop-history-thinking extension hides earlier thinking from the model, so
//    the call has to be quoted, not just mentioned.

const providers = new Set(["ninfer"]);
const maxNudgesInARow = 3;

function textOf(message: any, type: string, field: string): string {
  return (message?.content ?? [])
    .filter((block: any) => block?.type === type)
    .map((block: any) => block?.[field] ?? "")
    .join("");
}

function isStalled(message: any): boolean {
  if (message?.role !== "assistant" || !providers.has(message.provider) || message.stopReason !== "stop") return false;
  const hasText = textOf(message, "text", "text").trim().length > 0;
  const hasCall = (message.content ?? []).some((block: any) => block?.type === "toolCall");
  return !hasText && !hasCall;
}

// Qwen XML tool-call parameters are text; numbers, booleans, arrays and objects are JSON.
function parseValue(raw: string): unknown {
  const value = raw.replace(/^\n/, "").replace(/\n$/, "");
  if (/^\s*([[{]|-?\d+(\.\d+)?\s*$|true\s*$|false\s*$|null\s*$)/.test(value)) {
    try {
      return JSON.parse(value);
    } catch {
      // not JSON after all: keep the text
    }
  }
  return value;
}

// The last complete `<function=name>…</function>` in the thinking, as a tool call.
function rescueCall(thinking: string): { name: string; arguments: Record<string, unknown> } | undefined {
  const calls = [...thinking.matchAll(/<function=([^>\s]+)>([\s\S]*?)<\/function>/g)];
  const last = calls.at(-1);
  if (!last) return undefined;
  const args: Record<string, unknown> = {};
  for (const param of last[2].matchAll(/<parameter=([^>\s]+)>([\s\S]*?)<\/parameter>/g)) {
    args[param[1]] = parseValue(param[2]);
  }
  return Object.keys(args).length > 0 ? { name: last[1], arguments: args } : undefined;
}

function strandedCallText(thinking: string): string | undefined {
  const start = Math.max(thinking.lastIndexOf("<tool_call>"), thinking.lastIndexOf("<function="));
  return start === -1 ? undefined : thinking.slice(start);
}

export default function (pi: any) {
  let nudges = 0;

  pi.on("message_end", async (event: any) => {
    const message = event?.message;
    if (!isStalled(message)) return;
    const thinking = textOf(message, "thinking", "thinking");
    const call = rescueCall(thinking);
    if (!call) return;
    const cut = thinking.lastIndexOf("<tool_call>");
    const content = (message.content ?? []).map((block: any) =>
      block?.type === "thinking" && cut !== -1 ? { ...block, thinking: thinking.slice(0, cut).trimEnd() } : block,
    );
    content.push({
      type: "toolCall",
      id: `call_rescued_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`,
      name: call.name,
      arguments: call.arguments,
    });
    return { message: { ...message, content, stopReason: "toolUse" } };
  });

  pi.on("agent_end", async (event: any) => {
    const last = [...(event?.messages ?? [])].reverse().find((m: any) => m?.role === "assistant");
    const stranded = isStalled(last) ? strandedCallText(textOf(last, "thinking", "thinking")) : undefined;
    if (!stranded) {
      nudges = 0;
      return;
    }
    if (nudges >= maxNudgesInARow) return;
    nudges += 1;
    pi.sendUserMessage(
      "Your last reply wrote this tool call inside your thinking, so it did not run:\n\n" +
        stranded.trim().slice(0, 4000) +
        "\n\nClose your thinking first, then make that call (or a corrected one).",
      { deliverAs: "followUp" },
    );
  });
}
