# Casks/catassistant.rb
# This formula is for the homebrew-catassistant tap (github.com/jakobserlier/homebrew-catassistant)
# Copy this file to Casks/catassistant.rb in that repo.
#
# Usage:
#   brew tap jakobserlier/catassistant
#   brew install --cask catassistant
#
cask "catassistant" do
  version "0.8.2"

  on_arm do
    url "https://github.com/jakobserlier/catassistant/releases/download/v#{version}/catassistant-macOS-arm64.zip"
    sha256 "REPLACE_WITH_ARM64_SHA256"
  end
  on_intel do
    url "https://github.com/jakobserlier/catassistant/releases/download/v#{version}/catassistant-macOS-x86_64.zip"
    sha256 "REPLACE_WITH_X86_64_SHA256"
  end

  name "CatAssistant"
  desc "Monitor AI coding sessions from the macOS menu bar"
  homepage "https://github.com/jakobserlier/catassistant"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "CatAssistant.app"
  binary "#{appdir}/CatAssistant.app/Contents/MacOS/cathook"


  zap trash: [
    "~/.cat",
  ]
end
