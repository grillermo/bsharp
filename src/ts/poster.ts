// Poster reveal rules for Elisa: every TRIES_PER_TILE answers uncover one random tile.
// Pure functions only; reward.ts owns the DOM and localStorage.

export const GRID_COLS = 12;
export const GRID_ROWS = 9;
export const TILE_COUNT = GRID_COLS * GRID_ROWS;
export const TRIES_PER_TILE = 5;

export interface PosterState {
    posterIndex: number;
    revealed: number[];
    triesTowardNext: number;
}

export interface TryResult {
    state: PosterState;
    revealedTile: number | null;
    completed: boolean;
}

export function newPosterState(posterIndex = 0): PosterState {
    return { posterIndex, revealed: [], triesTowardNext: 0 };
}

function isTile(value: unknown): value is number {
    return Number.isInteger(value) && (value as number) >= 0 && (value as number) < TILE_COUNT;
}

export function recordTry(state: PosterState, rng: () => number = Math.random): TryResult {
    const revealed = new Set(state.revealed);
    if (revealed.size >= TILE_COUNT) {
        return { state, revealedTile: null, completed: true };
    }

    const tries = state.triesTowardNext + 1;
    if (tries < TRIES_PER_TILE) {
        return { state: { ...state, triesTowardNext: tries }, revealedTile: null, completed: false };
    }

    const covered: number[] = [];
    for (let i = 0; i < TILE_COUNT; i++) {
        if (!revealed.has(i)) covered.push(i);
    }
    const tile = covered[Math.floor(rng() * covered.length)];
    const next = { ...state, revealed: [...state.revealed, tile], triesTowardNext: 0 };
    return { state: next, revealedTile: tile, completed: next.revealed.length === TILE_COUNT };
}

export function startNextPoster(state: PosterState, posterCount: number): PosterState {
    return newPosterState((state.posterIndex + 1) % posterCount);
}

export function parsePosterState(raw: string | null, posterCount: number): PosterState {
    let data: unknown;
    try {
        data = raw === null ? null : JSON.parse(raw);
    } catch {
        return newPosterState();
    }
    if (data === null || typeof data !== 'object') return newPosterState();

    const d = data as Record<string, unknown>;
    const index = d.posterIndex;
    if (!Number.isInteger(index) || (index as number) < 0 || (index as number) >= posterCount) {
        return newPosterState();
    }

    const revealed = Array.isArray(d.revealed) ? [...new Set(d.revealed.filter(isTile))] : [];
    const tries = d.triesTowardNext;
    const triesTowardNext = Number.isInteger(tries) && (tries as number) >= 0 && (tries as number) < TRIES_PER_TILE
        ? tries as number
        : 0;
    return { posterIndex: index as number, revealed, triesTowardNext };
}
