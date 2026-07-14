class MatrixCo < Formula
  desc "Local-first multi-agent workspace with a terminal interface"
  homepage "https://matrix-co.pages.dev/"
  url "https://github.com/moonaries90/matrix-co-releases/releases/download/tui-v0.0.2/matrix-co-tui-0.0.2-darwin-arm64.tar.gz"
  sha256 "66bbfc3eabd6535c1aef6a4f9444603722a96b79d90d8963f09a59628384ebac"
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
