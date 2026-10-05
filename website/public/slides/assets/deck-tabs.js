/* deck-tabs.js: the data-driven parts of the CCS deck (SLD-04). Dependency-free.

   1. Reads the ONE data block <script type="application/json" id="deck-data"> that
      data/inject.mjs writes from data/case_study.json (+ the case_study.R code).
   2. Fills every [data-stat="path"] element (data-fmt: f2 = 2 decimals, p2 = signed
      percent, pp0 = fraction as percent, i = integer, i+1 = integer plus one, inv = N for 1 in N).
   3. Renders every [data-render="name"] host (tables, bar chart, line chart,
      histogram, code, console output) and every pre[data-code] (R code, coloured).
   4. Runs the pill tabs: .dt-tabs > .dt-pills > button.dt-pill[aria-pressed]
      with .dt-panel[data-tab] siblings. Exactly one panel of a group is visible.
      A pill click never advances the slide (stopPropagation; sigma's slides.js also
      ignores clicks on <button>). Keys 1-5 pick the nth pill of the current slide's
      tab groups; arrows, space, L, G etc. stay with the engine.

   No case-study number is typed in this file or in index.html. Only presentation
   labels (short event names, branch names) live here. Rule: never throw; a deck
   that half-loads must still page through. */
(function () {
  'use strict';

  /* ---------- the data block ---------- */
  var dataEl = document.getElementById('deck-data');
  var D = null;
  try { D = dataEl ? JSON.parse(dataEl.textContent) : null; } catch (e) { D = null; }

  var MINUS = '−', MID = '·', ARROW = '→';
  var C = { top: '#382a54', and: '#395d9c', or: '#3eb4ad', basic: '#def5e5', ink: '#0b0405',
            muted: '#3b4650', line: '#c5ccd3', panel: '#f5f7f8', hi: '#53c9ad', fn: '#60ceac', cm: '#a9e1bd' };
  var BRANCH_COLORS = ['#395d9c', '#3497a9', '#60ceac'];            // first, second, third child of the OR gate
  var BRANCH_NAMES = { EA: 'Outsider', UE: 'Unpatched flaw', IE: 'Insider' };
  var CALLNAME = { MN: 'MFA' };                                      // how the callout names an event
  var SHORT = { PC: 'Phished password', LR: 'Leaked password', MN: 'No MFA', PM: 'Admin access',
                VS: 'Known hole', PO: 'Late patching', WB: 'Web filter', IM: 'Insider acts',
                DA: 'Data copy-out', EP: 'Excess access' };

  /* ---------- helpers ---------- */
  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function get(path, root) {
    var cur = root === undefined ? D : root;
    var toks = String(path).replace(/\[(\d+)\]/g, '.$1').split('.');
    for (var i = 0; i < toks.length; i++) {
      if (cur === null || cur === undefined) return undefined;
      cur = cur[toks[i]];
    }
    return cur;
  }
  function fixed(v, n) { return Number(v).toFixed(n); }
  function signed(v) { return String(v).replace('-', MINUS); }
  function fmt(v, f) {
    if (v === undefined || v === null || (typeof v === 'number' && !isFinite(v))) return null;
    if (f === 'i+1') return String(Number(v) + 1);
    var m = /^([a-z]+)(\d*)$/.exec(f || '');
    var kind = m ? m[1] : '', n = m && m[2] !== '' ? Number(m[2]) : 0;
    if (kind === 'f') return signed(fixed(v, n));
    if (kind === 'p') return signed(fixed(v, n)) + '%';
    if (kind === 'pp') return signed(fixed(100 * v, n)) + '%';
    if (kind === 'i') return Number(v).toLocaleString('en-US', { maximumFractionDigits: 0 });
    if (kind === 'inv') return String(Math.round(1 / v));
    if (kind === 'x') return fixed(v, n);
    return String(v);
  }
  function mono(s, size, extra) {
    return '<span class="dt-mono" style="font-size:' + size + 'px;' + (extra || '') + '">' + s + '</span>';
  }

  /* ---------- derived structure (from the edges table, not typed) ---------- */
  var tree = null;
  function buildTree() {
    if (tree || !D) return tree;
    var kids = {}, types = {}, label = {};
    D.nodes.forEach(function (n) { types[n.event] = n.type; label[n.event] = n.label; });
    D.edges.forEach(function (e) { (kids[e.from_event] = kids[e.from_event] || []).push(e.to_event); });
    var top = D.nodes.filter(function (n) { return n.type === 'top'; })[0].event;
    var or = (kids[top] || [])[0];
    var branches = (kids[or] || []).map(function (g, i) {
      var leaves = [];
      (function walk(x) { (kids[x] || []).forEach(function (k) { if ((kids[k] || []).length) walk(k); else leaves.push(k); }); })(g);
      return { gate: g, color: BRANCH_COLORS[i % BRANCH_COLORS.length], name: BRANCH_NAMES[g] || g, leaves: leaves };
    });
    var of = {};
    branches.forEach(function (b) { b.leaves.forEach(function (l) { of[l] = b; }); });
    tree = { top: top, branches: branches, of: of, label: label };
    return tree;
  }
  function inputRow(ev) { return D.inputs.filter(function (r) { return r.event === ev; })[0]; }
  function meaningOf(ev) { var r = inputRow(ev); return r ? r.meaning : (buildTree().label[ev] || ev); }

  /* ---------- R / Python colouring (functions green, comments pale, like the static blocks) ---------- */
  function paintCode(code) {
    return String(code).split('\n').map(function (line) {
      var out = '', i = 0, q = null, start = 0;
      function flush(upto) {
        var seg = esc(line.slice(start, upto)).replace(/\b([A-Za-z_][A-Za-z0-9_]*)(?=\()/g,
          '<span style="color:' + C.fn + '">$1</span>');
        out += seg; start = upto;
      }
      for (; i < line.length; i++) {
        var ch = line[i];
        if (q) { if (ch === q) q = null; continue; }
        if (ch === '"' || ch === "'") { q = ch; continue; }
        if (ch === '#') {
          flush(i);
          out += '<span style="color:' + C.cm + '">' + esc(line.slice(i)) + '</span>';
          return out;
        }
      }
      flush(line.length);
      return out;
    }).join('\n');
  }

  /* ---------- renderers ---------- */
  var R = {};

  R.nodes = function (host) {
    var fill = { top: C.top, and: C.and, or: C.or, not: C.basic };
    var word = { top: 'top', and: 'and', or: 'or', not: 'not' };
    var rows = D.nodes.map(function (n, i) {
      var gate = n.type !== 'not';
      var firstBasic = !gate && D.nodes[i - 1] && D.nodes[i - 1].type !== 'not';
      var bg = gate ? 'background:' + C.panel + ';' : '';
      var bt = firstBasic ? 'border-top:1px solid ' + C.line + ';' : '';
      return '<tr style="' + bg + bt + '"><td style="font-weight:600;width:34px">' + esc(n.event) + '</td>' +
        '<td style="width:58px"><span style="display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px;background:' +
        fill[n.type] + ';border:1px solid ' + C.ink + '"></span>' + esc(word[n.type] || n.type) + '</td>' +
        '<td>' + esc(n.label) + '</td></tr>';
    }).join('');
    host.innerHTML = '<table class="dt-tbl dt-mono" style="font-size:14px;line-height:16px">' +
      '<thead><tr><th>event</th><th>type</th><th>label</th></tr></thead><tbody>' + rows + '</tbody></table>';
  };

  R.edges = function (host) {
    host.innerHTML = D.edges.map(function (e) {
      return mono(esc(e.from_event) + ' ' + ARROW + ' ' + esc(e.to_event), 14, 'line-height:18px;white-space:nowrap');
    }).join('');
  };

  R.rates = function (host) {
    var t = buildTree();
    var rows = D.inputs.map(function (r) {
      var b = t.of[r.event];
      return '<tr><td style="width:62px;font-weight:600"><span style="display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:8px;background:' +
        (b ? b.color : C.line) + '"></span>' + esc(r.event) + '</td>' +
        '<td style="font-family:\'Source Sans 3\',system-ui,sans-serif;font-size:18px">' + esc(r.meaning) + '</td>' +
        '<td class="r">' + fixed(r.lambda_per_year, 2) + '</td><td class="r">' + fixed(r.p_1yr, 3) + '</td></tr>';
    }).join('');
    host.innerHTML = '<table class="dt-tbl dt-mono" style="font-size:18px;line-height:31px">' +
      '<thead><tr><th>event</th><th>meaning</th><th class="r">λ / yr</th><th class="r">P(1 yr)</th></tr></thead><tbody>' + rows + '</tbody></table>';
  };

  function cutsetStats() {
    var count = {}, size = 0;
    D.cutsets.forEach(function (c) {
      var evs = c.cutset.split('*'); size = Math.max(size, evs.length);
      evs.forEach(function (e) { count[e] = (count[e] || 0) + 1; });
    });
    var max = 0; Object.keys(count).forEach(function (k) { max = Math.max(max, count[k]); });
    var shared = Object.keys(count).filter(function (k) { return count[k] === max && max > 1; });
    return { count: count, size: size, max: max, shared: shared };
  }
  function chip(ev) {
    return '<span class="dt-mono" style="background:' + C.hi + ';padding:0 6px;border-radius:4px">' + esc(ev) + '</span>';
  }

  R.cutsets = function (host) {
    var st = cutsetStats();
    var rows = D.cutsets.map(function (c) {
      var evs = c.cutset.split('*');
      var code = evs.map(function (e) { return st.shared.indexOf(e) >= 0 ? chip(e) : esc(e); }).join(' * ');
      var say = evs.map(function (e) { return esc(meaningOf(e)); }).join(' ' + MID + ' ');
      return '<div style="padding:5px 12px;background:' + C.panel + ';border:1px solid ' + C.line + ';border-radius:8px">' +
        '<div style="display:flex;justify-content:space-between;align-items:baseline">' +
        mono(code, 20, 'line-height:26px') + mono(fixed(c.p_1yr, 3), 20, 'line-height:26px;font-weight:500') + '</div>' +
        '<div style="font-size:14px;line-height:18px;color:' + C.muted + '">' + say + '</div></div>';
    }).join('');
    var shared = st.shared.map(chip).join(' and ');
    host.innerHTML =
      '<div style="display:flex;justify-content:space-between;font-size:14px;line-height:18px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:' + C.muted + ';margin-bottom:6px">' +
      '<span>Minimal cut sets · ' + D.cutsets.length + '</span><span>P(1 yr)</span></div>' +
      '<div style="display:flex;flex-direction:column;gap:7px">' + rows + '</div>' +
      '<ul style="margin:10px 0 0;padding:0;list-style:none;display:flex;flex-direction:column;gap:2px;font-size:22px;line-height:30px">' +
      '<li>Every path needs ' + st.size + ' failures</li>' +
      (shared ? '<li>' + shared + ' sit on ' + st.max + ' of ' + D.cutsets.length + '</li>' : '') + '</ul>';
  };

  function ratioStats() {
    var w = D.whatif, t = buildTree();
    var patch = (t.branches[1] || { leaves: [] }).leaves;
    var top2 = w.slice(0, 2);
    var topMean = top2.reduce(function (a, r) { return a + Math.abs(r.pct_change); }, 0) / top2.length;
    var pr = w.filter(function (r) { return patch.indexOf(r.event) >= 0; });
    var patchMean = pr.reduce(function (a, r) { return a + Math.abs(r.pct_change); }, 0) / (pr.length || 1);
    return { top2: top2, patch: patch, topMean: topMean, patchMean: patchMean, ratio: topMean / patchMean };
  }

  R.bars = function (host) {
    var w = D.whatif, t = buildTree();
    var max = Math.max.apply(null, w.map(function (r) { return Math.abs(r.pct_change); }));
    host.innerHTML = w.map(function (r) {
      var b = t.of[r.event], width = 80 * Math.abs(r.pct_change) / max;
      return '<div style="display:grid;grid-template-columns:230px minmax(0,1fr);align-items:center;height:30px;gap:12px">' +
        '<div style="font-size:18px;line-height:22px;white-space:nowrap">' + mono(esc(r.event), 18, 'font-weight:600') + ' ' +
        '<span style="color:' + C.muted + '">' + esc(SHORT[r.event] || r.meaning) + '</span></div>' +
        '<div style="display:flex;align-items:center;gap:10px;border-left:2px solid ' + C.ink + ';height:30px">' +
        '<div style="height:22px;width:' + width.toFixed(2) + '%;background:' + (b ? b.color : C.line) + ';border-radius:0 4px 4px 0"></div>' +
        mono(fmt(r.pct_change, 'p2'), 17, 'line-height:22px;white-space:nowrap') + '</div></div>';
    }).join('');
  };

  R.legend = function (host) {
    host.innerHTML = buildTree().branches.map(function (b) {
      return '<span style="display:inline-flex;align-items:center;gap:8px"><span style="width:16px;height:16px;border-radius:3px;background:' +
        b.color + '"></span>' + esc(b.name) + ' (' + esc(b.gate) + ')</span>';
    }).join('');
  };

  R.callout = function (host) {
    var s = ratioStats();
    var names = s.top2.map(function (r) { return CALLNAME[r.event] || SHORT[r.event] || r.event; }).join(' and ');
    host.innerHTML =
      '<div style="padding:20px 24px;background:' + C.hi + ';border-radius:8px;display:flex;flex-direction:column;gap:6px">' +
      '<div class="dt-mono" style="font-size:60px;line-height:64px;font-weight:500">~' + Math.round(s.ratio) + '×</div>' +
      '<div style="font-size:26px;line-height:32px;font-weight:600">' + esc(names) + ': ~' + Math.round(s.ratio) + '× the payoff of patching</div></div>' +
      '<div style="font-size:17px;line-height:23px;color:' + C.muted + '">Mean change in P(leak) from a 5% cut: ' +
      s.top2.map(function (r) { return esc(r.event); }).join(', ') + ' ' + fmt(-s.topMean, 'p2') + ' vs ' +
      s.patch.map(esc).join(', ') + ' ' + fmt(-s.patchMean, 'p2') + '</div>';
  };

  function svg(w, h, label, inner) {
    return '<svg viewBox="0 0 ' + w + ' ' + h + '" width="100%" role="img" aria-label="' + esc(label) +
      '" style="display:block;font-family:\'Source Sans 3\',system-ui,sans-serif">' + inner + '</svg>';
  }

  R.timeline = function (host) {
    var W = 780, H = 372, L = 58, Rm = 24, T = 20, B = 46;
    var pw = W - L - Rm, ph = H - T - B, pts = D.over_time;
    var maxY = 1, maxX = pts[pts.length - 1].years;
    function X(x) { return L + pw * x / maxX; }
    function Y(y) { return T + ph * (1 - y / maxY); }
    var s = '';
    [0, 0.25, 0.5, 0.75, 1].forEach(function (v) {
      s += '<line x1="' + L + '" x2="' + (W - Rm) + '" y1="' + Y(v) + '" y2="' + Y(v) + '" stroke="' + (v === 0 ? C.ink : '#e3e8ec') + '" stroke-width="' + (v === 0 ? 2 : 1) + '"/>' +
        '<text x="' + (L - 10) + '" y="' + (Y(v) + 5) + '" text-anchor="end" font-family="IBM Plex Mono, monospace" font-size="15" fill="' + C.muted + '">' + (v === 0 ? '0' : fixed(v, 2)) + '</text>';
    });
    for (var x = 0; x <= maxX; x += 2) {
      s += '<text x="' + X(x) + '" y="' + (H - 22) + '" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="15" fill="' + C.muted + '">' + x + '</text>';
    }
    s += '<text x="' + (L + pw / 2) + '" y="' + (H - 2) + '" text-anchor="middle" font-size="16" fill="' + C.muted + '">years</text>';
    var line = pts.map(function (p, i) { return (i ? 'L' : 'M') + X(p.years).toFixed(1) + ' ' + Y(p.p_top).toFixed(1); }).join(' ');
    s += '<path d="' + line + ' L' + X(maxX) + ' ' + Y(0) + ' L' + X(0) + ' ' + Y(0) + ' Z" fill="rgba(83,201,173,0.16)"/>';
    s += '<path d="' + line + '" fill="none" stroke="' + C.and + '" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/>';
    // annotations at three horizons: label sits up and to the left of its point
    var marks = [{ y: 1, dx: 12, dy: -40, anchor: 'start' }, { y: 5, dx: -20, dy: -12, anchor: 'end' }, { y: 10, dx: -16, dy: 44, anchor: 'end' }];
    marks.forEach(function (m) {
      var p = pts.filter(function (q) { return q.years === m.y; })[0];
      if (!p) return;
      var px = X(p.years), py = Y(p.p_top);
      s += '<line x1="' + px + '" x2="' + px + '" y1="' + py + '" y2="' + Y(0) + '" stroke="' + C.ink + '" stroke-width="1.5" stroke-dasharray="4 4"/>' +
        '<circle cx="' + px + '" cy="' + py + '" r="7" fill="' + C.hi + '" stroke="' + C.ink + '" stroke-width="2.5"/>' +
        '<text x="' + (px + m.dx) + '" y="' + (py + m.dy) + '" text-anchor="' + m.anchor + '" font-family="IBM Plex Mono, monospace" font-size="22" font-weight="500" fill="' + C.ink + '">' + fixed(p.p_top, 3) + '</text>' +
        '<text x="' + (px + m.dx) + '" y="' + (py + m.dy + 20) + '" text-anchor="' + m.anchor + '" font-size="16" fill="' + C.muted + '">' + (m.y === 1 ? '1 year' : m.y + ' years') + '</text>';
    });
    host.innerHTML = svg(W, H, 'P(top event) by year, 0 to ' + maxX + ' years', s);
  };

  R.hist = function (host) {
    var u = D.uncertainty, br = u.hist_breaks, ct = u.hist_counts;
    var lo = 0, hi = ct.length - 1;
    while (lo < hi && ct[lo] === 0) lo++;
    while (hi > lo && ct[hi] === 0) hi--;
    lo = Math.max(0, lo - 1); hi = Math.min(ct.length - 1, hi + 1);
    var x0 = br[lo], x1 = br[hi + 1], maxC = Math.max.apply(null, ct);
    var W = 700, H = 304, L = 12, Rm = 12, T = 62, B = 34;
    var pw = W - L - Rm, ph = H - T - B;
    function X(v) { return L + pw * (v - x0) / (x1 - x0); }
    var ramp = ['#382a54', '#413f80', '#395d9c', '#357ba3', '#3497a9', '#3eb4ad', '#53c9ad', '#60ceac', '#85d9b1'];
    var s = '';
    // the middle-90% band, then bars, then the median
    s += '<rect x="' + X(u.q05) + '" y="' + (T - 8) + '" width="' + (X(u.q95) - X(u.q05)) + '" height="' + (ph + 8) + '" fill="rgba(83,201,173,0.18)"/>' +
      '<line x1="' + X(u.q05) + '" x2="' + X(u.q05) + '" y1="' + (T - 8) + '" y2="' + (T + ph) + '" stroke="' + C.or + '" stroke-width="2" stroke-dasharray="6 4"/>' +
      '<line x1="' + X(u.q95) + '" x2="' + X(u.q95) + '" y1="' + (T - 8) + '" y2="' + (T + ph) + '" stroke="' + C.or + '" stroke-width="2" stroke-dasharray="6 4"/>';
    for (var i = lo; i <= hi; i++) {
      var h = ph * ct[i] / maxC, bx = X(br[i]) + 1.5, bw = X(br[i + 1]) - X(br[i]) - 3;
      if (!ct[i]) continue;
      s += '<rect x="' + bx.toFixed(1) + '" y="' + (T + ph - h).toFixed(1) + '" width="' + bw.toFixed(1) + '" height="' + h.toFixed(1) +
        '" rx="2" fill="' + ramp[Math.min(ramp.length - 1, Math.floor((1 - ct[i] / maxC) * ramp.length))] + '"/>';
    }
    s += '<line x1="' + L + '" x2="' + (W - Rm) + '" y1="' + (T + ph) + '" y2="' + (T + ph) + '" stroke="' + C.ink + '" stroke-width="2"/>';
    s += '<line x1="' + X(u.median) + '" x2="' + X(u.median) + '" y1="' + (T - 8) + '" y2="' + (T + ph) + '" stroke="' + C.ink + '" stroke-width="3"/>';
    s += '<text x="' + X(u.median) + '" y="' + (T - 40) + '" text-anchor="middle" font-size="18" font-weight="600" fill="' + C.ink + '">median ' + fixed(u.median, 3) + '</text>';
    s += '<text x="' + ((X(u.q05) + X(u.q95)) / 2) + '" y="' + (T - 16) + '" text-anchor="middle" font-size="17" fill="' + C.muted + '">90% of worlds ' + fixed(u.q05, 3) + ' ' + MINUS + ' ' + fixed(u.q95, 3) + '</text>';
    var step = 0.005;
    for (var v = Math.ceil(x0 / step) * step; v <= x1 + 1e-9; v += step) {
      s += '<text x="' + X(v) + '" y="' + (H - 10) + '" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="15" fill="' + C.muted + '">' + fixed(v, 3) + '</text>';
    }
    host.innerHTML = svg(W, H, 'Histogram of P(top event) over ' + u.n_worlds + ' worlds', s);
  };

  R.code = function (host) {
    var code = host.getAttribute('data-code').split(/\s+/).map(function (k) { return get('code.' + k); })
      .filter(Boolean).join('\n\n');
    if (code) host.innerHTML = paintCode(code);
  };

  R.out = function (host) {
    var which = host.getAttribute('data-out');             // twins_r | twins_py
    var o = D[which]; if (!o) return;
    var head = Array.isArray(o.calculate_head) ? o.calculate_head.join('\n') : String(o.calculate_head);
    var conc = Array.isArray(o.concentrate) ? o.concentrate.join('\n') : String(o.concentrate);
    var quant = Array.isArray(o.quantify) ? o.quantify.join('\n') : String(o.quantify);
    // each call's output in order, like a console; the R vector keeps its [1] index, Python prints a repr
    // R's tibble print already says how many rows it hides; pandas' head() does not.
    var more = /more rows/.test(head) ? '' : '\u2026 ' + o.calculate_rows + ' rows' + '\n';
    var lines = head + '\n' + more + conc + '\n' + quant;
    host.textContent = lines;
  };

  /* ---------- fill [data-stat] and [data-render] ---------- */
  function renderAll() {
    if (!D) return;
    [].forEach.call(document.querySelectorAll('[data-stat]'), function (el) {
      var v = get(el.getAttribute('data-stat'));
      var s = fmt(v, el.getAttribute('data-fmt'));
      if (s !== null) el.textContent = s;
    });
    [].forEach.call(document.querySelectorAll('[data-render]'), function (el) {
      var fn = R[el.getAttribute('data-render')];
      if (!fn) return;
      try { fn(el); } catch (e) { if (window.console) console.warn('deck-tabs: render failed', el.getAttribute('data-render'), e); }
    });
    [].forEach.call(document.querySelectorAll('pre[data-code]'), function (el) { try { R.code(el); } catch (e) { /* skip */ } });
    [].forEach.call(document.querySelectorAll('pre[data-out]'), function (el) { try { R.out(el); } catch (e) { /* skip */ } });
  }

  /* ---------- tabs ---------- */
  function pillsOf(group) { return [].slice.call(group.querySelectorAll(':scope > .dt-pills > .dt-pill')); }
  function panelsOf(group) { return [].slice.call(group.querySelectorAll(':scope > .dt-panel')); }
  function select(group, pill) {
    var name = pill.getAttribute('data-tab');
    pillsOf(group).forEach(function (p) { p.setAttribute('aria-pressed', p === pill ? 'true' : 'false'); });
    panelsOf(group).forEach(function (el) {
      if (el.getAttribute('data-tab') === name) el.removeAttribute('hidden'); else el.setAttribute('hidden', '');
    });
  }
  function initGroup(group) {
    var pills = pillsOf(group);
    if (!pills.length) return;
    var on = pills.filter(function (p) { return p.getAttribute('aria-pressed') === 'true'; })[0] || pills[0];
    pills.forEach(function (p, i) {
      if (!p.getAttribute('title')) p.setAttribute('title', 'Key ' + (i + 1));
      p.addEventListener('click', function (e) {
        e.stopPropagation();
        select(group, p);
        if (e.detail > 0) p.blur();                // a mouse click: give Space/arrows back to the deck
      });
    });
    select(group, on);
  }
  [].forEach.call(document.querySelectorAll('.dt-tabs'), initGroup);

  document.addEventListener('keydown', function (e) {
    if (e.metaKey || e.ctrlKey || e.altKey || e.shiftKey) return;
    if (!/^[1-5]$/.test(e.key)) return;
    var t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
    var slide = document.querySelector('.slide.is-active');
    if (!slide) return;
    var groups = [].slice.call(slide.querySelectorAll('.dt-tabs'));
    if (!groups.length) return;
    var n = Number(e.key) - 1, used = false;
    groups.forEach(function (g) { var p = pillsOf(g)[n]; if (p) { select(g, p); used = true; } });
    if (used) e.preventDefault();
  });

  renderAll();
})();
