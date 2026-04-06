PROJECT = menubar/Nekode.xcodeproj
DERIVED = menubar/build
SIGN = CODE_SIGN_IDENTITY="-"

.PHONY: all build test lint clean install run

all: lint build test

build:
	xcodebuild build -project $(PROJECT) -scheme Nekode -configuration Debug -derivedDataPath $(DERIVED) $(SIGN)
	xcodebuild build -project $(PROJECT) -scheme nekode -configuration Debug -derivedDataPath $(DERIVED) $(SIGN)
	mkdir -p $(DERIVED)/Build/Products/Debug/Nekode.app/Contents/Resources
	cp plugins/opencode/plugin.js $(DERIVED)/Build/Products/Debug/Nekode.app/Contents/Resources/opencode-plugin.js
	cp plugins/copilot/hooks/hooks.json $(DERIVED)/Build/Products/Debug/Nekode.app/Contents/Resources/copilot-hooks.json
	cp plugins/copilot/hooks/run-hook.sh $(DERIVED)/Build/Products/Debug/Nekode.app/Contents/Resources/copilot-run-hook.sh
	cp plugins/copilot-cli/hooks/hooks.json $(DERIVED)/Build/Products/Debug/Nekode.app/Contents/Resources/copilot-cli-hooks.json
	cp plugins/copilot-cli/hooks/run-hook.sh $(DERIVED)/Build/Products/Debug/Nekode.app/Contents/Resources/copilot-cli-run-hook.sh

test:
	xcodebuild test -project $(PROJECT) -scheme Nekode -configuration Debug -derivedDataPath $(DERIVED) $(SIGN)

lint:
	swiftlint lint --strict

clean:
	xcodebuild clean -project $(PROJECT) -scheme Nekode -derivedDataPath $(DERIVED)
	rm -rf $(DERIVED)

install:
	xcodebuild build -project $(PROJECT) -scheme nekode -configuration Release -derivedDataPath $(DERIVED) $(SIGN)
	mkdir -p ~/.nekode/bin
	cp $(DERIVED)/Build/Products/Release/nekode-cli ~/.nekode/bin/nekode

run: build
	open $(DERIVED)/Build/Products/Debug/Nekode.app
