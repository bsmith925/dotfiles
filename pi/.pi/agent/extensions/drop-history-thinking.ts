// Keep earlier assistant thinking out of requests to the local ninfer model.
//
// Pi replays every earlier thinking block as `reasoning_content`, and the
// Qwen3.8 chat template keeps it in the prompt. In long agentic turns Swift 1.5
// then copies its own boilerplate ("Let me be efficient. Let me start.") until
// a reply is nothing but repetition: in a replay of a looping session, thinking
// was 74-86% repeated with history thinking kept and 0% with it dropped, and
// the prompt shrank from 81k to 22k tokens. The session file keeps the thinking;
// only what is sent to the model changes.

const providers = new Set(["ninfer"]);

export default function (pi: any) {
  pi.on("context", (event: any, ctx: any) => {
    if (!providers.has(ctx?.model?.provider)) return;
    let changed = false;
    const messages = event.messages.map((message: any) => {
      if (message?.role !== "assistant" || !Array.isArray(message.content)) return message;
      const content = message.content.filter((block: any) => block?.type !== "thinking");
      if (content.length === message.content.length) return message;
      changed = true;
      return { ...message, content };
    });
    if (!changed) return;
    return { messages };
  });
}
