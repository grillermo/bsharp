// The Bluey characters shown as a reward after a correct answer. Each name matches a file in
// static/characters/ (cut out of the poster by tools/cut_characters.py).
export const CHARACTERS = [
    'dad', 'mum', 'nana', 'grandad', 'stripe', 'trixie',
    'indy', 'chloe', 'calypso', 'rusty', 'lucky', 'mackenzie',
    'bluey', 'bingo',
    'coco', 'jack', 'judo', 'socks', 'honey', 'muffin',
    'buddy', 'missy', 'bently', 'winton', 'terriers',
];

export const REVEAL_MS = 3000;

export function characterLabel(name: string): string {
    if (name === 'terriers') return 'The Terriers';
    return name.charAt(0).toUpperCase() + name.slice(1);
}

function shuffled(items: string[], rng: () => number): string[] {
    const out = [...items];
    for (let i = out.length - 1; i > 0; i--) {
        const j = Math.floor(rng() * (i + 1));
        [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
}

/** Returns a function that deals every character once per round, in random order. */
export function createCharacterDeck(rng: () => number = Math.random): () => string {
    let deck: string[] = [];
    let last = '';
    return () => {
        if (deck.length === 0) {
            deck = shuffled(CHARACTERS, rng);
            // Don't open a round with the character that closed the previous one.
            if (deck[deck.length - 1] === last) {
                [deck[0], deck[deck.length - 1]] = [deck[deck.length - 1], deck[0]];
            }
        }
        last = deck.pop()!;
        return last;
    };
}

const nextCharacter = createCharacterDeck();
let hideTimer: ReturnType<typeof setTimeout> | null = null;

export function isRevealing(): boolean {
    return hideTimer !== null;
}

/** Shows a character and its name, then hides it and calls onDone after REVEAL_MS. */
export function revealCharacter(onDone: () => void): void {
    const box = document.getElementById('character-reveal');
    if (!box) { onDone(); return; }
    const name = nextCharacter();
    const img = box.querySelector('img') as HTMLImageElement;
    img.src = `static/characters/${name}.png`;
    img.alt = characterLabel(name);
    (box.querySelector('.character-name') as HTMLElement).textContent = characterLabel(name);
    box.classList.add('visible');
    hideTimer = setTimeout(() => {
        hideTimer = null;
        box.classList.remove('visible');
        onDone();
    }, REVEAL_MS);
}
