import { getSessionHistory, getCurrentProfile } from './state';

let _isFirstIdentification = false;

function checkIsFirstSession(): boolean {
    const history = getSessionHistory();
    const profileHistory = history[String(getCurrentProfile().id)];
    if (!profileHistory) return true;
    for (const sessions of Object.values(profileHistory)) {
        for (const session of sessions) {
            if (session.identifications > 0) return false;
        }
    }
    return true;
}

const STEP_CONFIG: Record<string, { text: string; arrow: boolean }> = {
    play: { text: 'Toca el botón ▶ para escuchar', arrow: true },
    guess: { text: 'Adivina el color', arrow: false },
};

// The overlay is hidden until .visible is added, so measure after showing it.
function pointArrowAtPlayButton(overlay: HTMLElement, arrow: HTMLElement): void {
    const play = document.getElementById('play-button');
    if (!play) return;
    overlay.classList.add('visible');
    const overlayBox = overlay.getBoundingClientRect();
    const playBox = play.getBoundingClientRect();
    arrow.style.alignSelf = 'flex-start';
    arrow.style.marginLeft = `${playBox.left + playBox.width / 2 - overlayBox.left}px`;
}

function showOverlay(step: string): void {
    if (!getCurrentProfile().enable_onboarding_hints) return;
    const overlay = document.getElementById('onboarding-overlay');
    if (!overlay) return;
    const config = STEP_CONFIG[step];
    if (!config) return;

    overlay.dataset.step = step;
    overlay.innerHTML = '';

    if (config.arrow) {
        const arrow = document.createElement('div');
        arrow.className = 'onboarding-arrow';
        arrow.textContent = '\u2191';
        overlay.appendChild(arrow);
        pointArrowAtPlayButton(overlay, arrow);
    }

    const text = document.createElement('span');
    text.className = 'onboarding-text';
    text.textContent = config.text;
    overlay.appendChild(text);

    overlay.classList.add('visible');
}

function hideOverlay(): void {
    const overlay = document.getElementById('onboarding-overlay');
    if (!overlay) return;
    overlay.classList.remove('visible');
}

export function initOnboarding(): void {
    _isFirstIdentification = checkIsFirstSession();
    showOverlay('play');
}

export function resetOnboarding(): void {
    _isFirstIdentification = checkIsFirstSession();
    if (!getCurrentProfile().enable_onboarding_hints) {
        hideOverlay();
    }
}

export function showOnboardingPlayPrompt(): void {
    showOverlay('play');
}

export function dismissOnboardingStep(step: string): void {
    const overlay = document.getElementById('onboarding-overlay');
    if (overlay?.dataset.step === step) {
        hideOverlay();
    }
}

export function showOnboardingGuessPrompt(): void {
    if (_isFirstIdentification) {
        showOverlay('guess');
    }
}

/** A correct answer ends the first-session hints; the next chord follows by itself. */
export function completeOnboardingIdentification(): void {
    hideOverlay();
    _isFirstIdentification = false;
}
