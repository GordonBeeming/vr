#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
service_name="VR Resize Video.workflow"
service_dir="$HOME/Library/Services/$service_name"
service_contents="$service_dir/Contents"
install_bin_dir="$HOME/.local/bin"
installed_bin_path="$install_bin_dir/vr"
pbs_plist="$HOME/Library/Preferences/pbs.plist"
service_status_key="(null) - VR Resize Video - runWorkflowAsService"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "vr installer currently supports macOS only." >&2
  exit 1
fi

for tool in swift ffmpeg ffprobe; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing dependency: $tool" >&2
    if [[ "$tool" == "swift" ]]; then
      echo "Install Swift / Xcode Command Line Tools with: xcode-select --install" >&2
    else
      echo "Install ffmpeg with: brew install ffmpeg" >&2
    fi
    exit 1
  fi
done

swift build -c release --package-path "$repo_dir"
bin_path="$(swift build -c release --package-path "$repo_dir" --show-bin-path)/vr"

mkdir -p "$install_bin_dir"
ln -sfn "$bin_path" "$installed_bin_path"

mkdir -p "$service_contents"

cat > "$service_contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSBackgroundColorName</key>
      <string>background</string>
      <key>NSIconName</key>
      <string>NSTouchBarPlayTemplate</string>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>VR Resize Video</string>
      </dict>
      <key>NSMessage</key>
      <string>runWorkflowAsService</string>
      <key>NSRequiredContext</key>
      <dict>
        <key>NSApplicationIdentifier</key>
        <string>com.apple.finder</string>
      </dict>
      <key>NSSendFileTypes</key>
      <array>
        <string>public.item</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

cat > "$service_contents/document.wflow" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>AMApplicationBuild</key>
  <string>521</string>
  <key>AMApplicationVersion</key>
  <string>2.10</string>
  <key>AMDocumentVersion</key>
  <string>2</string>
  <key>actions</key>
  <array>
    <dict>
      <key>action</key>
      <dict>
        <key>ActionBundlePath</key>
        <string>/System/Library/Automator/Run Shell Script.action</string>
        <key>ActionName</key>
        <string>Run Shell Script</string>
        <key>ActionParameters</key>
        <dict>
          <key>COMMAND_STRING</key>
          <string>"$installed_bin_path" --dialog "\$@"</string>
          <key>CheckedForUserDefaultShell</key>
          <true/>
          <key>inputMethod</key>
          <integer>1</integer>
          <key>shell</key>
          <string>/bin/zsh</string>
          <key>source</key>
          <string></string>
        </dict>
        <key>AMAccepts</key>
        <dict>
          <key>Container</key>
          <string>List</string>
          <key>Optional</key>
          <true/>
          <key>Types</key>
          <array>
            <string>com.apple.cocoa.string</string>
          </array>
        </dict>
        <key>AMActionVersion</key>
        <string>2.0.3</string>
        <key>AMApplication</key>
        <array>
          <string>Automator</string>
        </array>
        <key>AMParameterProperties</key>
        <dict>
          <key>CheckedForUserDefaultShell</key>
          <dict/>
          <key>COMMAND_STRING</key>
          <dict/>
          <key>inputMethod</key>
          <dict/>
          <key>shell</key>
          <dict/>
          <key>source</key>
          <dict/>
        </dict>
        <key>AMProvides</key>
        <dict>
          <key>Container</key>
          <string>List</string>
          <key>Types</key>
          <array>
            <string>com.apple.cocoa.string</string>
          </array>
        </dict>
        <key>arguments</key>
        <dict>
          <key>0</key>
          <dict>
            <key>default value</key>
            <integer>0</integer>
            <key>name</key>
            <string>inputMethod</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>0</string>
          </dict>
          <key>1</key>
          <dict>
            <key>default value</key>
            <false/>
            <key>name</key>
            <string>CheckedForUserDefaultShell</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>1</string>
          </dict>
          <key>2</key>
          <dict>
            <key>default value</key>
            <string></string>
            <key>name</key>
            <string>source</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>2</string>
          </dict>
          <key>3</key>
          <dict>
            <key>default value</key>
            <string></string>
            <key>name</key>
            <string>COMMAND_STRING</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>3</string>
          </dict>
          <key>4</key>
          <dict>
            <key>default value</key>
            <string>/bin/sh</string>
            <key>name</key>
            <string>shell</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>4</string>
          </dict>
        </dict>
        <key>BundleIdentifier</key>
        <string>com.apple.RunShellScript</string>
        <key>CanShowSelectedItemsWhenRun</key>
        <false/>
        <key>CanShowWhenRun</key>
        <true/>
        <key>Category</key>
        <array>
          <string>AMCategoryUtilities</string>
        </array>
        <key>CFBundleVersion</key>
        <string>2.0.3</string>
        <key>Class Name</key>
        <string>RunShellScriptAction</string>
        <key>InputUUID</key>
        <string>F6F6483C-07CE-4D7F-A854-9DD18E1D1D49</string>
        <key>isViewVisible</key>
        <integer>1</integer>
        <key>Keywords</key>
        <array>
          <string>Shell</string>
          <string>Script</string>
          <string>Command</string>
          <string>Run</string>
          <string>Unix</string>
        </array>
        <key>location</key>
        <string>620.500000:484.000000</string>
        <key>nibPath</key>
        <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
        <key>OutputUUID</key>
        <string>E7687179-33BC-4621-9E8F-1DBE27CA9DD9</string>
        <key>UnlocalizedApplications</key>
        <array>
          <string>Automator</string>
        </array>
        <key>UUID</key>
        <string>8C5FD334-3B4B-4BA1-831D-4B3953C9D4BC</string>
      </dict>
      <key>isViewVisible</key>
      <integer>1</integer>
    </dict>
  </array>
  <key>connectors</key>
  <dict/>
  <key>workflowMetaData</key>
  <dict>
    <key>applicationBundleID</key>
    <string>com.apple.finder</string>
    <key>applicationBundleIDsByPath</key>
    <dict>
      <key>/System/Library/CoreServices/Finder.app</key>
      <string>com.apple.finder</string>
    </dict>
    <key>applicationPath</key>
    <string>/System/Library/CoreServices/Finder.app</string>
    <key>applicationPaths</key>
    <array>
      <string>/System/Library/CoreServices/Finder.app</string>
    </array>
    <key>inputTypeIdentifier</key>
    <string>com.apple.Automator.fileSystemObject</string>
    <key>outputTypeIdentifier</key>
    <string>com.apple.Automator.nothing</string>
    <key>presentationMode</key>
    <integer>15</integer>
    <key>processesInput</key>
    <false/>
    <key>serviceApplicationBundleID</key>
    <string>com.apple.finder</string>
    <key>serviceApplicationPath</key>
    <string>/System/Library/CoreServices/Finder.app</string>
    <key>serviceInputTypeIdentifier</key>
    <string>com.apple.Automator.fileSystemObject</string>
    <key>serviceOutputTypeIdentifier</key>
    <string>com.apple.Automator.nothing</string>
    <key>serviceProcessesInput</key>
    <false/>
    <key>systemImageName</key>
    <string>NSTouchBarPlayTemplate</string>
    <key>useAutomaticInputType</key>
    <false/>
    <key>workflowTypeIdentifier</key>
    <string>com.apple.Automator.servicesMenu</string>
  </dict>
</dict>
</plist>
PLIST

plutil -lint "$service_contents/Info.plist" "$service_contents/document.wflow" >/dev/null

mkdir -p "$(dirname "$pbs_plist")"
service_status_path=":NSServicesStatus:\"$service_status_key\""
/usr/libexec/PlistBuddy -c "Delete $service_status_path" "$pbs_plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add $service_status_path dict" "$pbs_plist"
/usr/libexec/PlistBuddy -c "Add $service_status_path:enabled_context_menu bool true" "$pbs_plist"
/usr/libexec/PlistBuddy -c "Add $service_status_path:enabled_services_menu bool false" "$pbs_plist"
/usr/libexec/PlistBuddy -c "Add $service_status_path:presentation_modes dict" "$pbs_plist"
/usr/libexec/PlistBuddy -c "Add $service_status_path:presentation_modes:ContextMenu bool true" "$pbs_plist"
/usr/libexec/PlistBuddy -c "Add $service_status_path:presentation_modes:FinderPreview bool true" "$pbs_plist"
/usr/libexec/PlistBuddy -c "Add $service_status_path:presentation_modes:ServicesMenu bool false" "$pbs_plist"
/usr/libexec/PlistBuddy -c "Add $service_status_path:presentation_modes:TouchBar bool true" "$pbs_plist"

if [[ -x /System/Library/CoreServices/pbs ]]; then
  /System/Library/CoreServices/pbs -flush || true
  /System/Library/CoreServices/pbs -update English >/dev/null 2>&1 || true
fi

killall Finder >/dev/null 2>&1 || true

echo "Installed vr:"
echo "  CLI: $install_bin_dir/vr"
echo "  Finder Quick Action: $service_dir"
echo
echo "Finder was restarted so the Quick Action can reload."
