class RemoteDevKit < Formula
  desc "Run and hot-reload your project on a remote VPS — no local Docker, code stays local"
  homepage "https://github.com/Enochthedev/remote-dev-kit"
  head "https://github.com/Enochthedev/remote-dev-kit.git", branch: "main"
  license "MIT"

  depends_on "docker" => :optional

  def install
    libexec.install "stacks"
    (libexec/"bin").install "bin/rdk"
    # thin wrapper on PATH that points rdk at its bundled stacks
    (bin/"rdk").write <<~SH
      #!/bin/bash
      export RDK_HOME="#{libexec}"
      exec "#{libexec}/bin/rdk" "$@"
    SH
    chmod 0755, bin/"rdk"
  end

  test do
    output = shell_output("#{bin}/rdk 2>&1", 1)
    assert_match "usage: rdk", output
  end
end
