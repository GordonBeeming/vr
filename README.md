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

## Troubleshooting

If Finder says the service is not configured correctly, rerun:

```bash
./install.sh
```

The installer regenerates the Automator workflow, enables its Finder visibility entry, refreshes the Services cache, and restarts Finder.
