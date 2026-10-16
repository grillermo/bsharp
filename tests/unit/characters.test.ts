import { describe, it, expect } from 'vitest';
import { CHARACTERS, createCharacterDeck, characterLabel } from '../../src/ts/characters';

describe('createCharacterDeck', () => {
    it('shows every character once before any repeats', () => {
        const next = createCharacterDeck(() => 0.3);
        const firstRound = Array.from({ length: CHARACTERS.length }, () => next());
        expect(new Set(firstRound).size).toBe(CHARACTERS.length);
        expect([...firstRound].sort()).toEqual([...CHARACTERS].sort());
    });

    it('reshuffles after a full round', () => {
        const next = createCharacterDeck(() => 0.5);
        for (let i = 0; i < CHARACTERS.length; i++) next();
        const secondRound = Array.from({ length: CHARACTERS.length }, () => next());
        expect(new Set(secondRound).size).toBe(CHARACTERS.length);
    });

    it('never repeats the last card of a round as the first of the next', () => {
        for (let seed = 0; seed < 50; seed++) {
            let s = seed + 1;
            const rng = () => { s = (s * 16807) % 2147483647; return s / 2147483647; };
            const next = createCharacterDeck(rng);
            let last = '';
            for (let i = 0; i < CHARACTERS.length * 3; i++) {
                const c = next();
                expect(c).not.toBe(last);
                last = c;
            }
        }
    });
});

describe('characterLabel', () => {
    it('capitalises the file name', () => {
        expect(characterLabel('dad')).toBe('Dad');
        expect(characterLabel('mackenzie')).toBe('Mackenzie');
        expect(characterLabel('terriers')).toBe('The Terriers');
    });
});
