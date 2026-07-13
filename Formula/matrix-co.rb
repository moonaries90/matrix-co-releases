class MatrixCo < Formula
  desc "Local-first multi-agent workspace with a terminal interface"
  homepage "https://matrix-co.pages.dev/"
  url "https://github.com/moonaries90/matrix-co-releases/releases/download/tui-v0.0.1/matrix-co-tui-0.0.1-darwin-arm64.tar.gz"
  sha256 "7ba614efda348c3c21c49f8ffff999d7f9b74d778c755b356e98ba8273f9cad9"
  license "MIT"

  depends_on arch: :arm64
  depends_on macos: :big_sur

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/matrix"
    bin.install_symlink libexec/"bin/matrixctl"
    bin.install_symlink libexec/"bin/matrix-co-tui"
  end

  def caveats
    <<~EOS
      Node.js 18 or later is required only for the Claude SDK and experimental
      Cursor SDK transports. Third-party agent CLIs are installed separately.
    EOS
  end

  test do
    assert_match "full-screen TUI for matrixd", shell_output("#{bin}/matrix --help")
    assert_match "manage local AgentProfile definitions", shell_output("#{bin}/matrixctl agent --help")
  end
end
