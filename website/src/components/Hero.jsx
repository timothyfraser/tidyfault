import InstallBlock from "./InstallBlock.jsx";

export default function Hero() {
  return (
    <div className="hero">
      <div className="hero-copy">
        <span className="eyebrow">An R and Python package</span>
        <h1>Fault tree analysis with tidy tables</h1>
        <p className="lede">
          A fault tree is two tables: nodes and edges. tidyfault turns them into the boolean
          equation, the truth table, the minimal cut sets and the top-event probability, in six
          verbs you can pipe, then draws the tree with ggplot2 or matplotlib.
        </p>
        <div className="row">
          <a className="btn btn-run" href="#start">
            ▶ Try it in the browser
          </a>
          <a className="btn btn-ghost" href="#install">
            Install
          </a>
        </div>
      </div>
      <div className="hero-install">
        <InstallBlock />
      </div>
    </div>
  );
}
