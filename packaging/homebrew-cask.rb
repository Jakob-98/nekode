# Casks/nekode.rb
# This formula is for the homebrew-nekode tap (github.com/jakobserlier/homebrew-nekode)
# Copy this file to Casks/nekode.rb in that repo.
#
# Usage:
#   brew tap jakobserlier/nekode
#   brew install --cask nekode
#
cask "nekode" do
  version "0.8.2"

  on_arm do
    url "https://github.com/jakobserlier/nekode/releases/download/v#{version}/nekode-macOS-arm64.zip"
    sha256 "REPLACE_WITH_ARM64_SHA256"
  end
  on_intel do
    url "https://github.com/jakobserlier/nekode/releases/download/v#{version}/nekode-macOS-x86_64.zip"
    sha256 "REPLACE_WITH_X86_64_SHA256"
  end

  name "Nekode"
  desc "Monitor AI coding sessions from the macOS menu bar"
  homepage "https://nekode.dev"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Nekode.app"
  binary "#{appdir}/Nekode.app/Contents/MacOS/nekode"

  zap trash: [
    "~/.nekode",
  ]
end
