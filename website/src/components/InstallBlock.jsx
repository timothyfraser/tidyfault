import Code from "./Code.jsx";

// The pip line breaks after `pip install` with a shell continuation, and the block wraps
// rather than clipping, so the whole command stays visible in the narrow hero column.
const INSTALL = `# R
remotes::install_github("timothyfraser/tidyfault")

# Python
pip install \\
"git+https://github.com/timothyfraser/tidyfault#subdirectory=python"`;

export default function InstallBlock() {
  return (
    <div className="stack-sm" id="install">
      <span className="eyebrow">Install</span>
      <pre className="code" style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>
        <Code text={INSTALL} />
      </pre>
    </div>
  );
}
