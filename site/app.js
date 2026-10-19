const MINUTE = 60;
const MODES = {
  focus: { seconds: 25 * MINUTE, rest: false },
  short: { seconds: 5 * MINUTE, rest: true },
  long: { seconds: 15 * MINUTE, rest: true },
};
const STEPS_PER_STAIR = 4;
const STEP_MIN_HEIGHT = 14;
const STEP_HEIGHT_GAIN = 14;
const RING_RADIUS = 100;
const RING_LENGTH = 2 * Math.PI * RING_RADIUS;
const TICK_MS = 250;
const STORAGE_KEY = "peyderpey:v1";

const $ = (id) => document.getElementById(id);
const els = {
  time: $("time"), label: $("label"), toggle: $("toggle"),
  reset: $("reset"), skip: $("skip"), steps: $("steps"), stats: $("stats"),
  ring: document.querySelector(".ring-fill"),
  modes: document.querySelectorAll(".mode"),
};

const state = {
  mode: "focus",
  remaining: MODES.focus.seconds,
  endsAt: null,
  timerId: null,
  step: 0,
  today: loadToday(),
};

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function loadToday() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
    return saved.date === todayKey() ? saved.count : 0;
  } catch {
    return 0;
  }
}

function saveToday() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ date: todayKey(), count: state.today }));
  } catch {
    // Storage may be unavailable (private mode); the counter just won't persist.
  }
}

function format(seconds) {
  const m = String(Math.floor(seconds / MINUTE)).padStart(2, "0");
  const s = String(seconds % MINUTE).padStart(2, "0");
  return `${m}:${s}`;
}

function labelText() {
  if (state.mode === "focus") return `${state.step + 1}. pey`;
  return state.mode === "long" ? "merdiven tamam, dinlen" : "kısa nefes";
}

function renderSteps() {
  els.steps.replaceChildren(...Array.from({ length: STEPS_PER_STAIR }, (_, i) => {
    const el = document.createElement("div");
    el.className = "step";
    el.style.height = `${STEP_MIN_HEIGHT + i * STEP_HEIGHT_GAIN}px`;
    if (i < state.step) el.classList.add("done");
    else if (i === state.step && state.mode === "focus") el.classList.add("current");
    return el;
  }));
}

function render() {
  const total = MODES[state.mode].seconds;
  els.time.textContent = format(state.remaining);
  els.label.textContent = labelText();
  els.ring.style.strokeDashoffset = String(RING_LENGTH * (1 - state.remaining / total));
  els.toggle.textContent = state.timerId ? "Duraklat" : "Başla";
  els.stats.textContent = `Bugün ${state.today} pey`;
  document.title = state.timerId ? `${format(state.remaining)} · peyderpey` : "peyderpey";
  document.body.classList.toggle("rest", MODES[state.mode].rest);
  els.modes.forEach((b) => b.setAttribute("aria-selected", String(b.dataset.mode === state.mode)));
  renderSteps();
}

function stop() {
  clearInterval(state.timerId);
  state.timerId = null;
  state.endsAt = null;
}

function setMode(mode) {
  stop();
  state.mode = mode;
  state.remaining = MODES[mode].seconds;
  render();
}

function tick() {
  state.remaining = Math.max(0, Math.round((state.endsAt - Date.now()) / 1000));
  if (state.remaining === 0) complete();
  render();
}

function start() {
  state.endsAt = Date.now() + state.remaining * 1000;
  state.timerId = setInterval(tick, TICK_MS);
  render();
}

function toggle() {
  if (state.timerId) {
    stop();
    render();
    return;
  }
  start();
}

function nextMode() {
  if (state.mode !== "focus") return "focus";
  return state.step === 0 ? "long" : "short";
}

function complete() {
  if (state.mode === "focus") {
    state.step = (state.step + 1) % STEPS_PER_STAIR;
    state.today += 1;
    saveToday();
  }
  chime();
  setMode(nextMode());
}

function reset() {
  setMode(state.mode);
}

function chime() {
  try {
    const ctx = new AudioContext();
    [523.25, 659.25, 783.99].forEach((freq, i) => playNote(ctx, freq, i * 0.18));
  } catch {
    // Audio is optional.
  }
}

function playNote(ctx, freq, delay) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  const t = ctx.currentTime + delay;
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0.2, t);
  gain.gain.exponentialRampToValueAtTime(0.001, t + 0.6);
  osc.connect(gain).connect(ctx.destination);
  osc.start(t);
  osc.stop(t + 0.6);
}

els.ring.style.strokeDasharray = String(RING_LENGTH);
els.toggle.addEventListener("click", toggle);
els.reset.addEventListener("click", reset);
els.skip.addEventListener("click", () => setMode(state.mode === "focus" ? "short" : "focus"));
els.modes.forEach((b) => b.addEventListener("click", () => setMode(b.dataset.mode)));
document.addEventListener("keydown", (e) => {
  if (e.code !== "Space" || e.target.closest("button")) return;
  e.preventDefault();
  toggle();
});
render();
