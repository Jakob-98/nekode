PROJECT = menubar/CatAssistant.xcodeproj
DERIVED = menubar/build
SIGN = CODE_SIGN_IDENTITY="-"

.PHONY: all build test lint clean install run

all: lint build test

build:
	xcodebuild build -project $(PROJECT) -scheme CatAssistant -configuration Debug -derivedDataPath $(DERIVED) $(SIGN)
	xcodebuild build -project $(PROJECT) -scheme cathook -configuration Debug -derivedDataPath $(DERIVED) $(SIGN)
	xcodebuild build -project $(PROJECT) -scheme catwait -configuration Debug -derivedDataPath $(DERIVED) $(SIGN)
	mkdir -p $(DERIVED)/Build/Products/Debug/CatAssistant.app/Contents/Resources
	cp plugins/opencode/plugin.js $(DERIVED)/Build/Products/Debug/CatAssistant.app/Contents/Resources/opencode-plugin.js

test:
	xcodebuild test -project $(PROJECT) -scheme CatAssistant -configuration Debug -derivedDataPath $(DERIVED) $(SIGN)

lint:
	swiftlint lint --strict

clean:
	xcodebuild clean -project $(PROJECT) -scheme CatAssistant -derivedDataPath $(DERIVED)
	rm -rf $(DERIVED)

install:
	xcodebuild build -project $(PROJECT) -scheme cathook -configuration Release -derivedDataPath $(DERIVED) $(SIGN)
	xcodebuild build -project $(PROJECT) -scheme catwait -configuration Release -derivedDataPath $(DERIVED) $(SIGN)
	mkdir -p ~/.cat/bin
	cp $(DERIVED)/Build/Products/Release/cathook ~/.cat/bin/cathook
	cp $(DERIVED)/Build/Products/Release/catwait ~/.cat/bin/catwait

run: build
	open $(DERIVED)/Build/Products/Debug/CatAssistant.app
