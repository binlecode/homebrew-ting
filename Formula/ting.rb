class Ting < Formula
  desc "Agent-first media engine with a terminal face: search, play, control mpv"
  homepage "https://github.com/binlecode/ting"
  url "https://github.com/binlecode/ting/archive/refs/tags/v0.23.0.tar.gz"
  sha256 "40119f6e67cbd2c1a5efcb6dec45383a74d9a079d8837f1a01ccc1f7b7ce7e77"
  license "MIT"

  depends_on "go" => :build
  depends_on "jq"
  depends_on "mpv"
  depends_on "yt-dlp"

  # Six scripts and one Go binary, sharing no library: four public commands (ting, the TUI,
  # is the binary) and three engine files. Every one locates VERSION and the shipped `config`
  # one level above its own RESOLVED path, walking any symlink chain first, so the tree has to
  # be installed whole and the bins have to be symlinks into it. The TUI is built into
  # libexec/shell/ting, where the script it replaced lived, so that rule holds unchanged and
  # it finds ting-play beside itself.
  #
  # Only the four public commands go on PATH. The engines (ting-engine-yt, ting-engine-bili,
  # ting-engine-ne) are ting-play's internal protocol, not a contract: ting-play finds them
  # beside its own resolved path, in libexec/shell, and every engine verb is reached as
  # `ting-play --search/--info/--items/--transcript/--auth`.
  def install
    libexec.install "shell", "config", "VERSION"
    system "go", "build", "-trimpath", "-o", libexec/"shell/ting", "./cmd/ting"
    %w[ting ting-play ting-playlist ting-history].each { |cmd| bin.install_symlink libexec/"shell/#{cmd}" }
    doc.install "README.md", "docs"
  end

  def caveats
    <<~EOS
      Playback needs a netcat that speaks unix sockets for the runtime control verbs
      (--pause, --seek, --set-volume, --set-loop). macOS ships one; on Linux install
      netcat-openbsd or nmap's ncat.

      As of 0.19.0 the public commands are ting, ting-play, ting-playlist and ting-history;
      t-play, t-playlist, t-history and the six yt-/bili-/ne-search/-resolve commands are
      gone. Every engine verb is `ting-play --search/--info/--items/--transcript/--auth`.
      Every config key is TING_-prefixed (TING_<KEY>, engine keys TING_<ENGINE>_<KEY>); a
      config file is read only for TING_ keys, so rename any old keys in
      ~/.config/ting/config. The pre-rename locations (~/.config/uting,
      ~/.local/state/uting) are no longer read.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ting --version")
    assert_match version.to_s, shell_output("#{bin}/ting-play --version")
    # The lifecycle half answers without a network: no player is a real, empty answer.
    assert_match "\"players\":[]", shell_output("#{bin}/ting-play --status -j")
    # Dropping the legacy lookup arms could only have broken one thing: the TUI finding its
    # own player. WHICH gate answers first depends on what the test machine has on PATH — a
    # missing unix-socket netcat speaks before the tty gate does — so the claim is the
    # negative one, which holds under every gate: it never gets as far as not finding ting-play.
    refute_match "cannot locate", shell_output("#{bin}/ting q </dev/null 2>&1 || true")
    # ting-play finds its engines in libexec, not on PATH: all three answer, each with flags.
    engines = shell_output("#{bin}/ting-play --engines -j")
    %w[yt bili ne].each { |e| assert_match "\"name\":\"#{e}\"", engines }
    refute_match "\"flags\":[]", engines
  end
end
