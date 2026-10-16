.PHONY: build serve deploy check clean test test-unit test-ui test-integration test-screenshot test-screenshot-update test-android-touch android-deploy android-release icons generate-audio move-downloaded-chords move-downloaded-notes convert-audio-to-mp3 play-store-screenshots agents-setup

build: dist/bsharp.js dist/style.css dist/index.html dist/static

serve: build
	npx http-server dist -p 8080 -c-1

DEPLOY_HOST := macmini
DEPLOY_DIR := c/elisa-www

deploy:
	rm -rf dist
	$(MAKE) build
	rsync -az --delete -e "ssh -o BatchMode=yes" dist/ $(DEPLOY_HOST):$(DEPLOY_DIR)/

dist/bsharp.js: src/ts/*.ts
	npx esbuild src/ts/main.ts --bundle --outfile=dist/bsharp.js --format=iife --target=es2020

dist/style.css: src/scss/*.scss
	npx sass src/scss/style.scss dist/style.css --no-source-map

# Cloudflare and Safari keep the JS and CSS for hours, so their URLs carry a content hash:
# a deploy that changes them changes the URL, and index.html (never cached) points at it.
dist/index.html: src/index.html dist/bsharp.js dist/style.css
	sed -e "s|href=\"style.css\"|href=\"style.css?v=$$(cksum < dist/style.css | cut -d' ' -f1)\"|" \
	    -e "s|src=\"bsharp.js\"|src=\"bsharp.js?v=$$(cksum < dist/bsharp.js | cut -d' ' -f1)\"|" \
	    src/index.html > dist/index.html

dist/static: static
	cp -r static dist/

check:
	npx tsc --noEmit

test-unit:
	npx vitest run

test-ui: build
	npx playwright test --config tests/playwright.config.ts

test: test-unit build
	npx playwright test --config tests/playwright.config.ts

test-integration: build
	npx playwright test --config tests/playwright.integration.config.ts

test-screenshot: build
	npx playwright test --config tests/playwright.screenshot.config.ts

test-screenshot-update: build
	npx playwright test --config tests/playwright.screenshot.config.ts --update-snapshots=all

test-android-touch: android-deploy
	npx playwright install android
	cd android && ./gradlew installDebug
	npx playwright test --config tests/android/playwright.android.config.ts

android-deploy: build
	rm -rf android/app/src/main/assets/*
	mkdir -p android/app/src/main/assets
	cp -r dist/* android/app/src/main/assets/

android-release: android-deploy
	cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew bundleRelease
	@echo "AAB: android/app/build/outputs/bundle/release/app-release.aab"

icons:
	bash scripts/generate_icons.sh

play-store-screenshots: build
	npx http-server dist -p 8080 -c-1 --silent & echo $$! > .http-server.pid
	sleep 1
	npx tsx scripts/play-store-screenshots.ts; kill $$(cat .http-server.pid); rm -f .http-server.pid

agents-setup:
	ln -sfn dev/AGENTS_MASTER.md AGENTS.md
	ln -sfn dev/AGENTS_MASTER.md CLAUDE.md

clean:
	rm -rf dist/*
	rm -rf android/app/src/main/assets/*
	rm -rf android/app/build

# --- Audio generation (one-time, requires browser + ffmpeg) ---

generate-audio:
	@echo "Starting local server for audio generation..."
	@echo "Use the buttons to generate chords, notes, or both."
	@echo "Allow multiple downloads when prompted. Press Ctrl+C when done."
	@sleep 2
	@open "http://localhost:8000/scripts/generate_audio.html" 2>/dev/null || xdg-open "http://localhost:8000/scripts/generate_audio.html" 2>/dev/null || echo "Open http://localhost:8000/scripts/generate_audio.html"
	npx http-server . -p 8000 -c-1

move-downloaded-chords:
	@mkdir -p static/chords
	@if ls ~/Downloads/*_*_*.wav >/dev/null 2>&1; then \
		count=$$(ls ~/Downloads/*_*_*.wav 2>/dev/null | wc -l); \
		mv ~/Downloads/*_*_*.wav static/chords/ && \
		echo "Moved $$count chord WAV files to static/chords/"; \
	else \
		echo "No chord WAV files found in ~/Downloads/"; \
	fi

move-downloaded-notes:
	@mkdir -p static/notes
	@if ls ~/Downloads/*[0-9]_*.wav >/dev/null 2>&1; then \
		count=$$(ls ~/Downloads/*[0-9]_*.wav 2>/dev/null | wc -l); \
		mv ~/Downloads/*[0-9]_*.wav static/notes/ && \
		echo "Moved $$count note WAV files to static/notes/"; \
	else \
		echo "No note WAV files found in ~/Downloads/"; \
	fi

convert-audio-to-mp3:
	@if ! command -v ffmpeg >/dev/null 2>&1; then \
		echo "ERROR: ffmpeg not found. Install with: brew install ffmpeg"; \
		exit 1; \
	fi
	@for dir in static/chords static/notes; do \
		if ls $$dir/*.wav >/dev/null 2>&1; then \
			cd $$dir && \
			for wav in *.wav; do \
				[ -f "$$wav" ] || continue; \
				ffmpeg -i "$$wav" -acodec libmp3lame -b:a 128k "$${wav%.wav}.mp3" -y -loglevel error && rm "$$wav"; \
			done && \
			cd - >/dev/null && \
			echo "Converted $$dir WAVs to MP3"; \
		fi; \
	done
