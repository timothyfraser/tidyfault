import NavBar from "../components/NavBar.jsx";
import Hero from "../components/Hero.jsx";
import PipelineStrip from "../components/PipelineStrip.jsx";
import RunChunk from "../components/RunChunk.jsx";
import FeatureCards from "../components/FeatureCards.jsx";
import ArticlesGrid from "../components/ArticlesGrid.jsx";
import ReferenceIndex from "../components/ReferenceIndex.jsx";
import Footer from "../components/Footer.jsx";

export default function Home() {
  return (
    <div className="page">
      <NavBar />
      <main className="page-main">
        <section className="section hero-section" id="top">
          <Hero />
          <PipelineStrip />
        </section>
        <section className="section" id="start">
          <div className="stack-sm">
            <span className="eyebrow">Get started</span>
            <h2>Run the whole pipeline here, nothing to install</h2>
            <p className="lede-sm">
              The package runs in your browser: R through webR, Python through Pyodide. The first
              run downloads the runtime (about a minute); later runs are instant.
            </p>
          </div>
          <RunChunk />
        </section>
        <FeatureCards />
        <ArticlesGrid />
        <ReferenceIndex />
      </main>
      <Footer />
    </div>
  );
}
