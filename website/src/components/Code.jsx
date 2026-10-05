// Tiny syntax highlighter for the static chunks: comments and function calls.
const NOT_FUNCTIONS = new Set(["c"]);
const TOKEN = /((?:^|\s)#.*$)|([A-Za-z_][\w]*)(?=\()/gm;

export default function Code({ text }) {
  const parts = [];
  let last = 0;
  let key = 0;
  for (const m of text.matchAll(TOKEN)) {
    if (m.index > last) parts.push(text.slice(last, m.index));
    if (m[1] !== undefined) {
      const lead = m[1].match(/^\s*/)[0];
      parts.push(lead, <span key={key++} className="cm">{m[1].slice(lead.length)}</span>);
    } else if (NOT_FUNCTIONS.has(m[2])) {
      parts.push(m[2]);
    } else {
      parts.push(<span key={key++} className="kw">{m[2]}</span>);
    }
    last = m.index + m[0].length;
  }
  parts.push(text.slice(last));
  return <>{parts}</>;
}
