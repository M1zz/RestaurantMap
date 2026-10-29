// 인생맛집 웹 데모: 방문 기록의 맛 평가를 그대로 해 보고, 식당 화면의 총평 차트와 리이오미슐랭 점수를 본다.
// 규칙은 앱과 같다 — 항목은 EvaluationType.evaluationAttributes(음식마다 6개), 맛 강도 0~10(0.5 단위), 만족도 1~5,
// 처음 값은 AddVisitView 와 같이 강도 5 · 만족도 3 · 별점 3. 차트는 CalibratedRadarChartForVisit:
// 파란 선 = 맛의 형태(강도), 초록 면 = 강도 × 만족도/5. 점수는 Restaurant.satisfactionScore: 별점 50% + 만족도 50%.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

  let type = 0, rating = 3, vals;
  const reset = () => { vals = T.types[type].attrs.map(() => ({ v: 5, s: 3 })); };
  reset();

  root.innerHTML = `
    <div class="rm-form">
      <div class="rm-types" role="group">${T.types.map((t, i) =>
        `<button type="button" class="rm-type" data-type="${i}" aria-pressed="${i === type}">${t.emoji} ${esc(t.name)}</button>`).join("")}</div>
      <div class="rm-stars" role="group" aria-label="${esc(T.rating)}"><span>${esc(T.rating)}</span>${[1, 2, 3, 4, 5].map(n =>
        `<button type="button" data-star="${n}" aria-label="${esc(T.rating)} ${n}">★</button>`).join("")}</div>
      <div class="rm-rows"></div>
    </div>
    <div class="rm-result">
      <div class="rm-legend"><span class="rm-shape">${esc(T.shape)}</span><span class="rm-sat">${esc(T.sat)}</span></div>
      <svg class="rm-radar" viewBox="-160 -150 320 300" aria-hidden="true"></svg>
      <p class="rm-score" aria-live="polite"><span>${esc(T.score)}</span><b>0</b><small>/ 100</small></p>
      <p class="muted small">${esc(T.note)}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const rows = $(".rm-rows"), svg = $(".rm-radar"), scoreEl = $(".rm-score b");

  function buildRows() {
    rows.innerHTML = T.types[type].attrs.map(([emoji, title, sub], i) => `
      <div class="rm-row">
        <div class="rm-head"><b>${emoji} ${esc(title)}</b><span class="muted small">${esc(sub)}</span></div>
        <label class="rm-slider"><span class="muted small">${esc(T.intensity)}</span>
          <input type="range" min="0" max="10" step="0.5" value="${vals[i].v}" data-i="${i}" aria-label="${esc(title)} ${esc(T.intensity)}"></label>
        <div class="rm-sats" role="group" aria-label="${esc(title)} ${esc(T.sat)}">
          <span class="muted small">${esc(T.sat)}</span>${[1, 2, 3, 4, 5].map(n =>
            `<button type="button" data-i="${i}" data-s="${n}" aria-label="${esc(T.sat)} ${n}">${n}</button>`).join("")}
        </div>
        <div class="rm-ends muted small"><span>${esc(T.low)}</span><span>${esc(T.high)}</span></div>
      </div>`).join("");
  }

  const R = 100, point = (i, r) => {
    const a = 2 * Math.PI * i / 6 - Math.PI / 2;
    return [Math.cos(a) * r, Math.sin(a) * r];
  };
  const poly = f => vals.map((_, i) => point(i, f(i)).map(n => n.toFixed(1)).join(",")).join(" ");

  function render() {
    root.querySelectorAll("[data-type]").forEach(b => b.setAttribute("aria-pressed", +b.dataset.type === type));
    root.querySelectorAll("[data-star]").forEach(b => b.classList.toggle("on", +b.dataset.star <= rating));
    root.querySelectorAll("[data-s]").forEach(b => b.setAttribute("aria-pressed", vals[b.dataset.i].s === +b.dataset.s));
    const grid = [1, 2, 3, 4, 5].map(l => `<polygon class="rm-grid" points="${poly(() => R * l / 5)}"/>`).join("");
    const axes = vals.map((_, i) => `<line class="rm-grid" x1="0" y1="0" x2="${point(i, R)[0]}" y2="${point(i, R)[1]}"/>`).join("");
    const labels = T.types[type].attrs.map(([, title], i) => {
      const [x, y] = point(i, R + 22), anchor = Math.abs(x) < 1 ? "middle" : x > 0 ? "start" : "end";
      return `<text x="${x.toFixed(1)}" y="${(y + 4).toFixed(1)}" text-anchor="${anchor}">${esc(title)}</text>`;
    }).join("");
    svg.innerHTML = grid + axes +
      `<polygon class="rm-fill" points="${poly(i => R * vals[i].v / 10 * vals[i].s / 5)}"/>` +
      `<polygon class="rm-line" points="${poly(i => R * vals[i].v / 10)}"/>` + labels;
    const avgSat = vals.reduce((n, x) => n + x.s, 0) / vals.length;
    scoreEl.textContent = Math.round(rating / 5 * 100 * 0.5 + avgSat / 5 * 100 * 0.5);
  }

  root.addEventListener("input", e => {
    if (e.target.type === "range") { vals[e.target.dataset.i].v = +e.target.value; render(); }
  });
  root.addEventListener("click", e => {
    const b = e.target.closest("button");
    if (!b) return;
    if (b.dataset.type) { type = +b.dataset.type; reset(); buildRows(); }
    if (b.dataset.star) rating = +b.dataset.star;
    if (b.dataset.s) vals[b.dataset.i].s = +b.dataset.s;
    render();
  });

  buildRows();
  render();
})();
