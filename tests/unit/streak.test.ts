import { describe, it, expect } from 'vitest';
import { STREAK_TARGET, nextStreak, nextLevel, streakProgress } from '../../src/ts/streak';

describe('nextStreak', () => {
    it('adds one for a correct answer', () => {
        expect(nextStreak(0, true)).toBe(1);
        expect(nextStreak(7, true)).toBe(8);
    });

    it('goes back to zero on a miss', () => {
        expect(nextStreak(7, false)).toBe(0);
        expect(nextStreak(0, false)).toBe(0);
    });
});

describe('streakProgress', () => {
    it('is the share of the target, clamped to 0..1', () => {
        expect(streakProgress(0)).toBe(0);
        expect(streakProgress(STREAK_TARGET / 2)).toBe(0.5);
        expect(streakProgress(STREAK_TARGET)).toBe(1);
        expect(streakProgress(STREAK_TARGET + 5)).toBe(1);
        expect(streakProgress(-3)).toBe(0);
    });
});

describe('nextLevel', () => {
    const levels = ['red', 'yellow', 'blue'];

    it('returns the level after the current one', () => {
        expect(nextLevel('red', levels)).toBe('yellow');
        expect(nextLevel('yellow', levels)).toBe('blue');
    });

    it('returns null at the last level or for an unknown level', () => {
        expect(nextLevel('blue', levels)).toBeNull();
        expect(nextLevel('pink', levels)).toBeNull();
    });
});
