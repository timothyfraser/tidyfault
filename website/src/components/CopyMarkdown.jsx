// "Copy as Markdown": fetches the page's generated .md file (scripts/build-llms.mjs writes it
// into dist/ next to the HTML routes, so the button and /llms.txt share one source) and puts
// it on the clipboard. Falls back from ClipboardItem to writeText to a hidden textarea; if
// nothing works the label says so and the .md link is offered instead.
import { useEffect, useRef, useState } from "react";

async function copyText(href) {
  const get = async () => {
    const res = await fetch(href, { headers: { Accept: "text/markdown, text/plain" } });
    // A host that rewrites unknown paths to index.html answers 200 with HTML, which is not the page.
    const text = await res.text();
    if (!res.ok || /^\s*<(!doctype|html)/i.test(text)) throw new Error(`no Markdown at ${href}`);
    return text;
  };
  // ClipboardItem takes a promise, so the write starts inside the click (Safari requires that).
  if (typeof ClipboardItem !== "undefined" && navigator.clipboard?.write) {
    try {
      await navigator.clipboard.write([new ClipboardItem({ "text/plain": get().then((t) => new Blob([t], { type: "text/plain" })) })]);
      return;
    } catch (err) {
      if (/no Markdown/.test(String(err?.message))) throw err;
    }
  }
  const text = await get();
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return;
    } catch {
      /* fall through to the textarea */
    }
  }
  const ta = document.createElement("textarea");
  ta.value = text;
  ta.setAttribute("readonly", "");
  ta.style.cssText = "position:fixed;top:0;left:0;opacity:0";
  document.body.appendChild(ta);
  ta.select();
  const done = document.execCommand?.("copy");
  ta.remove();
  if (!done) throw new Error("clipboard unavailable");
}

export default function CopyMarkdown({ href }) {
  const [state, setState] = useState("idle"); // idle | copied | failed
  const timer = useRef(null);
  useEffect(() => () => clearTimeout(timer.current), []);
  useEffect(() => setState("idle"), [href]);

  const onClick = async () => {
    clearTimeout(timer.current);
    try {
      await copyText(href);
      setState("copied");
    } catch {
      setState("failed");
    }
    timer.current = setTimeout(() => setState("idle"), 2000);
  };

  const label = state === "copied" ? "Copied" : state === "failed" ? "Copy failed" : "Copy as Markdown";
  return (
    <span data-copy-markdown="" style={{ display: "inline-flex", alignItems: "center", gap: "var(--space-3)" }}>
      <button type="button" className="btn btn-ghost btn-sm" onClick={onClick} title="Copy this page as Markdown, for pasting into an LLM or a coding agent">
        {label}
      </button>
      <span role="status" aria-live="polite" style={{ position: "absolute", width: 1, height: 1, overflow: "hidden", clip: "rect(0 0 0 0)" }}>
        {state === "copied" ? "Copied to clipboard" : state === "failed" ? "Could not copy" : ""}
      </span>
      {state === "failed" ? (
        <a href={href} style={{ fontSize: 14 }}>
          Open the Markdown
        </a>
      ) : null}
    </span>
  );
}
