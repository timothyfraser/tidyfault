import Code from "./Code.jsx";

const INSTALL = `# R
remotes::install_github("timothyfraser/tidyfault")

# Python
pip install "git+https://github.com/timothyfraser/tidyfault#subdirectory=python"`;

export default function InstallBlock() {
  return (
    <div className="stack-sm" id="install">
      <span className="eyebrow">Install</span>
      <pre className="code">
        <Code text={INSTALL} />
      </pre>
    </div>
  );
}
