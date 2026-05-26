# vr

`vr` is a macOS video resizing dev tool, not virtual reality.

It provides:

- a compiled command-line utility
- a Finder right-click Quick Action named `VR Resize Video`
- a native dialog for choosing resize presets

## Install

Prerequisites:

- macOS
- Swift toolchain / Xcode command line tools
- `ffmpeg` and `ffprobe`

```bash
brew install ffmpeg
./install.sh
```

The installer builds the Swift executable, symlinks it to `~/.local/bin/vr`, installs a Finder Quick Action into `~/Library/Services/VR Resize Video.workflow`, enables it in the Finder Quick Actions presentation list, and restarts Finder.

## Finder Usage

Right-click one or more video files in Finder, then choose:

```text
Quick Actions > VR Resize Video
```

Choose a preset in the dialog. The resized `.mp4` output is written next to the original file.

The dialog shows estimated output sizes for quality presets and target sizes for GitHub presets.

## CLI Usage

```bash
vr --preset half ~/Desktop/demo.mov
vr --preset 1080p ~/Desktop/demo.mov
vr --preset github-10mb ~/Desktop/demo.mov
vr --dialog ~/Desktop/demo.mov
vr --estimate ~/Desktop/demo.mov
```

Available presets:

- `half` - half resolution
- `1080p` - max long edge 1920 px
- `720p` - max long edge 1280 px
- `github-10mb` - target under 10 MB for GitHub issue/comment video uploads on free repos
- `github-100mb` - target under 100 MB for GitHub issue/comment video uploads on paid repos

GitHub currently documents video attachment limits as 10 MB for free user/org repositories and 100 MB for paid user/org repositories.

## Development

This repo is intentionally small. The Swift executable contains the CLI, the AppKit dialog, and the `ffmpeg` orchestration. The installer builds that executable and generates the Finder Quick Action that calls it.

### Repo Layout

```text
.
├── Package.swift          # Swift Package Manager manifest
├── Sources/vr/main.swift  # CLI, dialog, presets, estimates, ffmpeg calls
├── install.sh             # Builds and installs the CLI + Finder Quick Action
└── README.md              # User and developer docs
```

### Local Setup

Install dependencies:

```bash
xcode-select --install
brew install ffmpeg
```

Build the release binary:

```bash
swift build -c release
```

Run from the repo without installing:

```bash
.build/release/vr --list-presets
.build/release/vr --estimate ~/Desktop/demo.mov
.build/release/vr --preset half ~/Desktop/demo.mov
```

On Apple Silicon, SwiftPM may place the executable under an architecture-specific path such as `.build/arm64-apple-macosx/release/vr`. For scripts, prefer:

```bash
"$(swift build -c release --show-bin-path)/vr" --list-presets
```

### How It Works

`Sources/vr/main.swift` owns the runtime behavior:

- `Preset` defines the available resize modes and GitHub upload targets.
- `probe()` reads dimensions and duration with `ffprobe`.
- `estimateLabel()` produces the size text shown in the dialog and `--estimate`.
- `resizeCRF()` handles quality-based presets like `half`, `1080p`, and `720p`.
- `resizeToTarget()` does a two-pass bitrate encode for `github-10mb` and `github-100mb`.
- `runDialog()` shows the native AppKit preset picker used by Finder.

`install.sh` owns the macOS integration:

- Builds the release binary.
- Symlinks it to `~/.local/bin/vr`.
- Generates `~/Library/Services/VR Resize Video.workflow`.
- Points the Automator workflow at the installed symlink.
- Enables the service in Finder's Quick Actions presentation settings.
- Refreshes Services and restarts Finder.

The generated workflow is not checked in. Treat `install.sh` as the source of truth for Finder integration changes.

### Verification

Before opening a PR, run:

```bash
swift build -c release
"$(swift build -c release --show-bin-path)/vr" --list-presets
"$(swift build -c release --show-bin-path)/vr" --estimate /tmp/vr-test.mp4
./install.sh
```

To create a tiny test video:

```bash
ffmpeg -y -f lavfi -i testsrc=size=640x360:rate=15 -t 2 -pix_fmt yuv420p /tmp/vr-test.mp4
```

To simulate Finder's reduced environment:

```bash
PATH=/usr/bin:/bin:/usr/sbin:/sbin ~/.local/bin/vr --estimate /tmp/vr-test.mp4
```

### Finder Debugging

Check that the generated workflow is valid:

```bash
plutil -lint \
  "$HOME/Library/Services/VR Resize Video.workflow/Contents/Info.plist" \
  "$HOME/Library/Services/VR Resize Video.workflow/Contents/document.wflow"
```

Check the registered Services entry:

```bash
/System/Library/CoreServices/pbs -dump | rg -n "VR Resize Video" -C 8
```

Check Finder visibility settings:

```bash
defaults read pbs NSServicesStatus | rg -n "VR Resize Video" -A 8
```

If the Quick Action is missing or stale, rerun `./install.sh`. It regenerates the workflow, refreshes the Services cache, and restarts Finder.

## Troubleshooting

If Finder says the service is not configured correctly, rerun:

```bash
./install.sh
```

The installer regenerates the Automator workflow, enables its Finder visibility entry, refreshes the Services cache, and restarts Finder.
