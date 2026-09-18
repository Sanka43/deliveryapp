/**
 * MND Admin — vendored, zero-dependency SVG charts.
 *
 * Not a charting library: a handful of small inline-SVG builders, themed
 * entirely off the existing CSS custom properties (brand tokens), with a
 * <title>/<desc> and a visually-hidden data table for screen readers.
 * Kept dependency-free rather than pulling a chart library off a CDN —
 * see the mnd_web redesign plan (Phase 2, Dashboard) for the reasoning.
 */
(function (global) {
  function esc(s) {
    return global.MndDom ? global.MndDom.esc(s) : String(s == null ? "" : s);
  }

  // Catmull-Rom -> cubic Bezier smoothing, so trend lines read as soft
  // curves instead of sharp zig-zags between days. Endpoints repeat the
  // adjacent point as their own neighbor so the curve doesn't overshoot
  // past the first/last dot.
  function smoothPath(coords) {
    if (coords.length === 0) return "";
    if (coords.length === 1) return `M ${coords[0].x.toFixed(1)} ${coords[0].y.toFixed(1)}`;
    let d = `M ${coords[0].x.toFixed(1)} ${coords[0].y.toFixed(1)}`;
    for (let i = 0; i < coords.length - 1; i++) {
      const p0 = coords[i === 0 ? 0 : i - 1];
      const p1 = coords[i];
      const p2 = coords[i + 1];
      const p3 = coords[i + 2 < coords.length ? i + 2 : i + 1];
      const cp1x = p1.x + (p2.x - p0.x) / 6;
      const cp1y = p1.y + (p2.y - p0.y) / 6;
      const cp2x = p2.x - (p3.x - p1.x) / 6;
      const cp2y = p2.y - (p3.y - p1.y) / 6;
      d += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`;
    }
    return d;
  }

  /**
   * points: [{ label: string, value: number }, ...]
   * opts: { id, title, desc, xLabel, yLabel, width, height }
   */
  function renderLineChart(el, points, opts) {
    if (!el) return;
    opts = opts || {};
    const width = opts.width || 560;
    const height = opts.height || 180;
    const padding = { top: 16, right: 16, bottom: 28, left: 8 };
    const innerW = width - padding.left - padding.right;
    const innerH = height - padding.top - padding.bottom;

    if (!points || points.length === 0) {
      el.innerHTML = '<p class="u-text-muted u-text-sm">No data yet.</p>';
      return;
    }

    const values = points.map((p) => Number(p.value) || 0);
    const maxV = Math.max(1, ...values);
    const stepX = points.length > 1 ? innerW / (points.length - 1) : 0;
    const coords = points.map((p, i) => ({
      x: padding.left + i * stepX,
      y: padding.top + innerH - (Number(p.value) || 0) / maxV * innerH,
      label: p.label,
      value: Number(p.value) || 0,
    }));

    const pathD = smoothPath(coords);
    const floorY = (padding.top + innerH).toFixed(1);
    const areaD = `${pathD} L ${coords[coords.length - 1].x.toFixed(1)} ${floorY} L ${coords[0].x.toFixed(1)} ${floorY} Z`;

    const gridLines = [0.5, 1]
      .map((f) => {
        const y = (padding.top + innerH * f).toFixed(1);
        return `<line x1="${padding.left}" y1="${y}" x2="${width - padding.right}" y2="${y}" stroke="var(--border)" stroke-width="1"/>`;
      })
      .join("");

    const lastIdx = coords.length - 1;
    const dots = coords
      .map((c, i) =>
        i === lastIdx
          ? `<circle cx="${c.x.toFixed(1)}" cy="${c.y.toFixed(1)}" r="7" fill="var(--brand)" opacity="0.16"></circle>
             <circle cx="${c.x.toFixed(1)}" cy="${c.y.toFixed(1)}" r="4" fill="var(--brand)" stroke="var(--surface)" stroke-width="2"><title>${esc(c.label)}: ${esc(String(c.value))}</title></circle>`
          : `<circle cx="${c.x.toFixed(1)}" cy="${c.y.toFixed(1)}" r="2.5" fill="var(--surface)" stroke="var(--brand)" stroke-width="1.5"><title>${esc(c.label)}: ${esc(String(c.value))}</title></circle>`
      )
      .join("");

    const xLabels = coords
      .map(
        (c, i) =>
          `<text x="${c.x.toFixed(1)}" y="${height - 8}" font-size="10" fill="var(--muted-2)" text-anchor="${i === 0 ? "start" : i === coords.length - 1 ? "end" : "middle"}">${esc(c.label)}</text>`
      )
      .join("");

    const titleId = (opts.id || "chart") + "-title";
    const descId = (opts.id || "chart") + "-desc";
    const gradId = titleId + "-fill";

    const tableRows = points
      .map((p) => `<tr><td>${esc(p.label)}</td><td>${esc(String(p.value))}</td></tr>`)
      .join("");

    el.innerHTML = `
      <svg viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="${titleId} ${descId}" style="width:100%;height:auto;display:block">
        <title id="${titleId}">${esc(opts.title || "Trend chart")}</title>
        <desc id="${descId}">${esc(opts.desc || "")}</desc>
        <defs>
          <linearGradient id="${gradId}" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="var(--brand)" stop-opacity="0.22"></stop>
            <stop offset="100%" stop-color="var(--brand)" stop-opacity="0"></stop>
          </linearGradient>
        </defs>
        ${gridLines}
        <path d="${areaD}" fill="url(#${gradId})" stroke="none"></path>
        <path d="${pathD}" fill="none" stroke="var(--brand)" stroke-width="2.5" stroke-linecap="round"></path>
        ${dots}
        ${xLabels}
      </svg>
      <table class="sr-only">
        <caption>${esc(opts.title || "Trend chart")} — data table</caption>
        <thead><tr><th>${esc(opts.xLabel || "Label")}</th><th>${esc(opts.yLabel || "Value")}</th></tr></thead>
        <tbody>${tableRows}</tbody>
      </table>
    `;
  }

  /**
   * series: [{ name, color, points: [{label, value}, ...] }, ...] — all
   * lines are solid; only the first series gets a gradient fill.
   * All series must share the same point count/labels (one per x position).
   * opts: same as renderLineChart, minus per-series color (set per series).
   */
  function renderMultiLineChart(el, series, opts) {
    if (!el) return;
    opts = opts || {};
    const fmt = typeof opts.valueFormatter === "function" ? opts.valueFormatter : (v) => String(v);
    const width = opts.width || 560;
    const height = opts.height || 200;
    const padding = { top: 16, right: 16, bottom: 28, left: 8 };
    const innerW = width - padding.left - padding.right;
    const innerH = height - padding.top - padding.bottom;

    const pointCount = (series[0] && series[0].points && series[0].points.length) || 0;
    if (!series.length || pointCount === 0) {
      el.innerHTML = '<p class="u-text-muted u-text-sm">No data yet.</p>';
      return;
    }

    const allValues = series.reduce((acc, s) => acc.concat(s.points.map((p) => Number(p.value) || 0)), []);
    const maxV = Math.max(1, ...allValues);
    const stepX = pointCount > 1 ? innerW / (pointCount - 1) : 0;

    const gridLines = [0.5, 1]
      .map((f) => {
        const y = (padding.top + innerH * f).toFixed(1);
        return `<line x1="${padding.left}" y1="${y}" x2="${width - padding.right}" y2="${y}" stroke="var(--border)" stroke-width="1"/>`;
      })
      .join("");

    const titleId = (opts.id || "chart") + "-title";
    const descId = (opts.id || "chart") + "-desc";
    const defs = [];
    const seriesSvg = series
      .map((s, si) => {
        const color = s.color || "var(--brand)";
        const coords = s.points.map((p, i) => ({
          x: padding.left + i * stepX,
          y: padding.top + innerH - ((Number(p.value) || 0) / maxV) * innerH,
          label: p.label,
          value: Number(p.value) || 0,
        }));
        const pathD = smoothPath(coords);
        const lastIdx = coords.length - 1;
        const dots = coords
          .map((c, i) =>
            i === lastIdx
              ? `<circle cx="${c.x.toFixed(1)}" cy="${c.y.toFixed(1)}" r="5" fill="${color}" stroke="var(--surface)" stroke-width="2"><title>${esc(s.name)} · ${esc(c.label)}: ${esc(fmt(c.value))}</title></circle>`
              : `<circle cx="${c.x.toFixed(1)}" cy="${c.y.toFixed(1)}" r="2.5" fill="${color}" stroke="var(--surface)" stroke-width="1.5"><title>${esc(s.name)} · ${esc(c.label)}: ${esc(fmt(c.value))}</title></circle>`
          )
          .join("");
        // Only the primary (first) series gets a soft gradient fill under
        // its curve — filling every series would just muddy the overlaps
        // once several lines cross.
        let areaPath = "";
        if (si === 0) {
          const gradId = `${titleId}-fill-${si}`;
          const floorY = (padding.top + innerH).toFixed(1);
          const areaD = `${pathD} L ${coords[lastIdx].x.toFixed(1)} ${floorY} L ${coords[0].x.toFixed(1)} ${floorY} Z`;
          defs.push(
            `<linearGradient id="${gradId}" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="${color}" stop-opacity="0.18"></stop><stop offset="100%" stop-color="${color}" stop-opacity="0"></stop></linearGradient>`
          );
          areaPath = `<path d="${areaD}" fill="url(#${gradId})" stroke="none"></path>`;
        }
        return `${areaPath}<path d="${pathD}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linecap="round"></path>${dots}`;
      })
      .join("");

    const showEvery = pointCount > 10 ? Math.ceil(pointCount / 8) : 1;
    const xLabels = series[0].points
      .map((p, i) => ({ x: padding.left + i * stepX, label: p.label, i }))
      .filter((c) => c.i % showEvery === 0 || c.i === pointCount - 1)
      .map(
        (c) =>
          `<text x="${c.x.toFixed(1)}" y="${height - 8}" font-size="10" fill="var(--muted-2)" text-anchor="middle">${esc(c.label)}</text>`
      )
      .join("");

    const tableRows = series
      .map((s) => s.points.map((p) => `<tr><td>${esc(s.name)}</td><td>${esc(p.label)}</td><td>${esc(fmt(p.value))}</td></tr>`).join(""))
      .join("");

    const legend = series
      .map(
        (s) =>
          `<span class="chart-legend__item"><span class="chart-legend__swatch" style="background:${s.color || "var(--brand)"}"></span>${esc(s.name)}</span>`
      )
      .join("");

    el.innerHTML = `
      <svg viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="${titleId} ${descId}" style="width:100%;height:auto;display:block">
        <title id="${titleId}">${esc(opts.title || "Trend chart")}</title>
        <desc id="${descId}">${esc(opts.desc || "")}</desc>
        <defs>${defs.join("")}</defs>
        ${gridLines}
        ${seriesSvg}
        ${xLabels}
      </svg>
      <div class="chart-legend">${legend}</div>
      <table class="sr-only">
        <caption>${esc(opts.title || "Trend chart")} — data table</caption>
        <thead><tr><th>Series</th><th>${esc(opts.xLabel || "Label")}</th><th>${esc(opts.yLabel || "Value")}</th></tr></thead>
        <tbody>${tableRows}</tbody>
      </table>
    `;
  }

  global.MndCharts = { renderLineChart, renderMultiLineChart };
})(window);
