# HARDENING: devops-agent 2026-06-24

.PHONY: dev build test analyze clean

# Run local development server/app
dev:
	bash scripts/build_dev.sh

# Compile production APK release
build:
	bash scripts/build_prod.sh

# Run all unit/widget tests
test:
	flutter test

# Run code analysis (fail on warning)
analyze:
	dart analyze --fatal-infos --fatal-warnings

# Clean build artifacts
clean:
	flutter clean
	flutter pub get
