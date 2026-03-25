APP_NAME = EpycZones
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

.PHONY: build bundle run clean debug

# Release build
build:
	swift build -c release

# Debug build
debug:
	swift build

# Create .app bundle from release build
bundle: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	security unlock-keychain -p "" /tmp/epyczones-dev.keychain 2>/dev/null; \
	codesign --force --sign "EpycZones Dev" --keychain /tmp/epyczones-dev.keychain $(APP_BUNDLE)
	@echo "✅ $(APP_BUNDLE) created"

# Build and run
run: bundle
	open $(APP_BUNDLE)

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
