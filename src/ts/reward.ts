// DOM side of Elisa's poster rewards: thumbnail + progress ring, reveal overlay,
// answer feedback, completion party. Rules live in poster.ts.
import {
    PosterState, GRID_COLS, GRID_ROWS, TILE_COUNT, TRIES_PER_TILE,
    recordTry, startNextPoster, parsePosterState,
} from './poster';

export const POSTER_STATE_KEY = 'elisa_poster';
const POSTERS_URL = 'static/posters/posters.json';
const FLIP_DELAY_MS = 500;
const FEEDBACK_MS = 1500;
const CONFETTI_PIECES = 80;
const CONFETTI_COLORS = ['#ffca3a', '#f86468', '#77e0c7', '#5a5a87', '#8fd3fb', '#ffffff'];

interface PosterInfo { file: string; title: string; }

let _posters: PosterInfo[] = [];
let _state: PosterState | null = null;
let _feedbackTimer: ReturnType<typeof setTimeout> | null = null;

function el<T extends HTMLElement = HTMLElement>(id: string): T {
    return document.getElementById(id) as T;
}

function saveState(): void {
    localStorage.setItem(POSTER_STATE_KEY, JSON.stringify(_state));
}

function posterUrl(): string {
    return 'static/posters/' + _posters[_state!.posterIndex].file;
}

function renderTiles(container: HTMLElement, flipTile: number | null): void {
    container.innerHTML = '';
    container.style.gridTemplateColumns = `repeat(${GRID_COLS}, 1fr)`;
    container.style.gridTemplateRows = `repeat(${GRID_ROWS}, 1fr)`;
    const revealed = new Set(_state!.revealed);
    for (let i = 0; i < TILE_COUNT; i++) {
        const tile = document.createElement('div');
        tile.className = 'poster-tile';
        if (revealed.has(i) && i !== flipTile) tile.classList.add('revealed');
        container.appendChild(tile);
        if (i === flipTile) {
            tile.classList.add('flipping');
            setTimeout(() => tile.classList.add('revealed'), FLIP_DELAY_MS);
        }
    }
}

function renderThumb(): void {
    el<HTMLImageElement>('poster-thumb-img').src = posterUrl();
    renderTiles(el('poster-thumb-tiles'), null);
    const percent = (_state!.triesTowardNext / TRIES_PER_TILE) * 100;
    el('progress-ring-fill').setAttribute('stroke-dasharray', `${percent} 100`);
}

function playSound(id: string): void {
    const audio = el<HTMLAudioElement>(id);
    audio.currentTime = 0;
    audio.play().catch(() => { /* iOS refused: audio not primed yet */ });
}

function showPoster(message: string, flipTile: number | null): void {
    el('poster-message').textContent = message;
    el<HTMLImageElement>('poster-img').src = posterUrl();
    renderTiles(el('poster-tiles'), flipTile);
    el('poster-overlay').classList.add('visible');
}

function throwConfetti(): void {
    const confetti = el('confetti');
    confetti.innerHTML = '';
    for (let i = 0; i < CONFETTI_PIECES; i++) {
        const piece = document.createElement('span');
        piece.style.left = `${Math.random() * 100}%`;
        piece.style.background = CONFETTI_COLORS[i % CONFETTI_COLORS.length];
        piece.style.animationDelay = `${Math.random() * 1.5}s`;
        piece.style.animationDuration = `${2.5 + Math.random() * 2}s`;
        confetti.appendChild(piece);
    }
}

function showFeedback(isCorrect: boolean): void {
    const feedback = el('answer-feedback');
    feedback.textContent = isCorrect ? '¡Muy bien!' : '¡Inténtalo otra vez!';
    feedback.classList.add('visible');
    if (_feedbackTimer !== null) clearTimeout(_feedbackTimer);
    _feedbackTimer = setTimeout(() => feedback.classList.remove('visible'), FEEDBACK_MS);
}

export async function initRewards(): Promise<void> {
    try {
        const response = await fetch(POSTERS_URL);
        _posters = await response.json() as PosterInfo[];
    } catch {
        return; // No posters: the trainer still works, just without rewards.
    }
    if (_posters.length === 0) return;
    _state = parsePosterState(localStorage.getItem(POSTER_STATE_KEY), _posters.length);
    if (_state.revealed.length >= TILE_COUNT) {
        _state = startNextPoster(_state, _posters.length);
    }
    saveState();
    renderThumb();
}

export function onAnswer(isCorrect: boolean): void {
    showFeedback(isCorrect);
    if (_state === null) return;

    const result = recordTry(_state);
    _state = result.state;
    saveState();
    renderThumb();
    if (result.revealedTile === null) return;

    if (result.completed) {
        el('poster-overlay').classList.add('party');
        showPoster('¡Lo lograste, Elisa! ¡Terminaste el póster!', result.revealedTile);
        throwConfetti();
        playSound('party-audio');
    } else {
        showPoster('¡Muy bien, Elisa!', result.revealedTile);
        playSound('cheer-audio');
    }
}

export function openPoster(): void {
    if (_state === null) return;
    showPoster(_posters[_state.posterIndex].title, null);
}

export function closePoster(): void {
    const overlay = el('poster-overlay');
    overlay.classList.remove('visible', 'party');
    el('confetti').innerHTML = '';
    if (_state !== null && _state.revealed.length >= TILE_COUNT) {
        _state = startNextPoster(_state, _posters.length);
        saveState();
        renderThumb();
    }
}

// iOS only plays audio started from a user gesture. Call this from the first tap
// so the reward sounds can play later without one.
export function primeRewardAudio(): void {
    for (const id of ['cheer-audio', 'party-audio']) {
        const audio = el<HTMLAudioElement>(id);
        audio.muted = true;
        audio.play()
            .then(() => { audio.pause(); audio.currentTime = 0; audio.muted = false; })
            .catch(() => { audio.muted = false; });
    }
}
