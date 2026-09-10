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

    const pathD = coords.map((c, i) => `${i === 0 ? "M" : "L"} ${c.x.toFixed(1)} ${c.y.toFixed(1)}`).join(" ");
    const floorY = (padding.top + innerH).toFixed(1);
    const areaD = `${pathD} L ${coords[coords.length - 1].x.toFixed(1)} ${floorY} L ${coords[0].x.toFixed(1)} ${floorY} Z`;

    const gridLines = [0, 0.5, 1]
      .map((f) => {
        const y = (padding.top + innerH * f).toFixed(1);
        return `<line x1="${padding.left}" y1="${y}" x2="${width - padding.right}" y2="${y}" stroke="var(--border)" stroke-width="1"/>`;
      })
      .join("");

    const dots = coords
      .map(
        (c) =>
          `<circle cx="${c.x.toFixed(1)}" cy="${c.y.toFixed(1)}" r="3.5" fill="var(--brand)" stroke="var(--surface)" stroke-width="1.5"><title>${esc(c.label)}: ${esc(String(c.value))}</title></circle>`
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

    const tableRows = points
      .map((p) => `<tr><td>${esc(p.label)}</td><td>${esc(String(p.value))}</td></tr>`)
      .join("");

    el.innerHTML = `
      <svg viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="${titleId} ${descId}" style="width:100%;height:auto;display:block">
        <title id="${titleId}">${esc(opts.title || "Trend chart")}</title>
        <desc id="${descId}">${esc(opts.desc || "")}</desc>
        ${gridLines}
        <path d="${areaD}" fill="var(--brand-glow)" stroke="none"></path>
        <path d="${pathD}" fill="none" stroke="var(--brand)" stroke-width="2"></path>
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

  global.MndCharts = { renderLineChart };
})(window);
