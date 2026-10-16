// A streak of correct answers fills a thin outline around the page. At STREAK_TARGET in a row
// the game moves on to the next level; any miss sends the streak back to zero.
export const STREAK_TARGET = 20;

export function nextStreak(streak: number, correct: boolean): number {
    return correct ? streak + 1 : 0;
}

export function streakProgress(streak: number): number {
    return Math.min(1, Math.max(0, streak / STREAK_TARGET));
}

/** The level after `current` in `levels`, or null when it is the last (or unknown). */
export function nextLevel(current: string, levels: string[]): string | null {
    const i = levels.indexOf(current);
    return i >= 0 && i < levels.length - 1 ? levels[i + 1] : null;
}

const SVG_NS = 'http://www.w3.org/2000/svg';
const INSET = 3;
let _progress = 0;

// The outline is a rectangle path that starts top-centre and runs clockwise, drawn in real
// pixels so the stroke stays the same width on any screen. pathLength=1 turns the dash offset
// into a plain 0..1 fraction of the way round.
function outlinePath(w: number, h: number): string {
    const l = INSET, t = INSET, r = w - INSET, b = h - INSET, cx = w / 2;
    return `M${cx} ${t} H${r} V${b} H${l} V${t} H${cx}`;
}

function layoutOutline(): void {
    const svg = document.getElementById('streak-outline');
    if (!svg) return;
    const w = window.innerWidth, h = window.innerHeight;
    svg.setAttribute('viewBox', `0 0 ${w} ${h}`);
    svg.querySelectorAll('path').forEach(p => p.setAttribute('d', outlinePath(w, h)));
}

export function renderStreakOutline(streak: number): void {
    const fill = document.querySelector('#streak-outline .streak-fill') as SVGPathElement | null;
    if (!fill) return;
    const progress = streakProgress(streak);
    // A miss unwinds quickly; a hit fills slowly.
    fill.style.transitionDuration = progress < _progress ? '0.35s' : '0.9s';
    fill.style.strokeDashoffset = String(1 - progress);
    _progress = progress;
}

export function initStreakOutline(): void {
    layoutOutline();
    window.addEventListener('resize', layoutOutline);
}
