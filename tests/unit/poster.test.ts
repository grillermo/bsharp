import { describe, it, expect } from 'vitest';
import {
    TILE_COUNT, TRIES_PER_TILE, newPosterState, recordTry, startNextPoster, parsePosterState,
    PosterState,
} from '../../src/ts/poster';

function tryTimes(state: PosterState, times: number) {
    let result = { state, revealedTile: null as number | null, completed: false };
    for (let i = 0; i < times; i++) result = recordTry(result.state);
    return result;
}

describe('recordTry', () => {
    it('reveals nothing before the 5th try and one tile on it', () => {
        const before = tryTimes(newPosterState(), TRIES_PER_TILE - 1);
        expect(before.revealedTile).toBeNull();
        expect(before.state.revealed).toEqual([]);

        const fifth = recordTry(before.state);
        expect(fifth.revealedTile).not.toBeNull();
        expect(fifth.state.revealed).toEqual([fifth.revealedTile]);
        expect(fifth.state.triesTowardNext).toBe(0);
    });

    it('uncovers every tile exactly once and reports completion on the last', () => {
        let state = newPosterState();
        const seen: number[] = [];
        for (let tile = 0; tile < TILE_COUNT; tile++) {
            const result = tryTimes(state, TRIES_PER_TILE);
            seen.push(result.revealedTile!);
            expect(result.completed).toBe(tile === TILE_COUNT - 1);
            state = result.state;
        }
        expect(new Set(seen).size).toBe(TILE_COUNT);
        expect(seen.every(t => t >= 0 && t < TILE_COUNT)).toBe(true);
    });

    it('reveals nothing more once the poster is complete', () => {
        const full: PosterState = {
            posterIndex: 0, triesTowardNext: TRIES_PER_TILE - 1,
            revealed: Array.from({ length: TILE_COUNT }, (_, i) => i),
        };
        const result = recordTry(full);
        expect(result.revealedTile).toBeNull();
        expect(result.completed).toBe(true);
    });
});

describe('startNextPoster', () => {
    it('moves to the next poster with nothing revealed, wrapping after the last', () => {
        const done: PosterState = { posterIndex: 1, revealed: [3, 4], triesTowardNext: 2 };
        expect(startNextPoster(done, 3)).toEqual({ posterIndex: 2, revealed: [], triesTowardNext: 0 });
        expect(startNextPoster(done, 2)).toEqual({ posterIndex: 0, revealed: [], triesTowardNext: 0 });
    });
});

describe('parsePosterState', () => {
    it('starts fresh when nothing is stored or the JSON is corrupt', () => {
        expect(parsePosterState(null, 1)).toEqual(newPosterState());
        expect(parsePosterState('{not json', 1)).toEqual(newPosterState());
        expect(parsePosterState('"a string"', 1)).toEqual(newPosterState());
    });

    it('drops unknown and duplicate tiles and out-of-range counters', () => {
        const raw = JSON.stringify({ posterIndex: 0, revealed: [5, 5, -1, TILE_COUNT, 2.5, 'x', 7], triesTowardNext: 99 });
        expect(parsePosterState(raw, 1)).toEqual({ posterIndex: 0, revealed: [5, 7], triesTowardNext: 0 });
    });

    it('starts fresh when the stored poster no longer exists', () => {
        const raw = JSON.stringify({ posterIndex: 4, revealed: [1, 2], triesTowardNext: 3 });
        expect(parsePosterState(raw, 2)).toEqual(newPosterState());
    });
});
