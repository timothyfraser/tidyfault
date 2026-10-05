const ARTICLES = [
  ["Workflow", "Core workflow", "From two tables to minimal cut sets in six verbs."],
  ["Figures", "Visualizing fault trees", "Layouts, gate polygons, and your own ggplot layers."],
  ["Quantification", "Simulating uncertainty", "Probability intervals for the top event from event rates."],
];

export default function ArticlesGrid() {
  return (
    <section className="section" id="articles">
      <div className="section-head">
        <h2>Articles</h2>
        <a className="link-strong" href="#articles">
          All articles
        </a>
      </div>
      <div className="grid-3">
        {ARTICLES.map(([tag, title, blurb]) => (
          <a className="card card-link" href="#articles" key={title}>
            <span className="eyebrow">{tag}</span>
            <span className="card-title">{title}</span>
            <span className="card-text">{blurb}</span>
          </a>
        ))}
      </div>
    </section>
  );
}
