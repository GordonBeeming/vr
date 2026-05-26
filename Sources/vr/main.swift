import AppKit
import Foundation

enum VRFailure: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value):
            value
        }
    }
}

struct VideoInfo {
    let width: Int
    let height: Int
    let duration: Double
}

struct VideoSource {
    let url: URL
    let info: VideoInfo
    let sizeBytes: Int64
}

enum Preset: String, CaseIterable {
    case half
    case longEdge1080 = "1080p"
    case longEdge720 = "720p"
    case github10 = "github-10mb"
    case github100 = "github-100mb"

    var title: String {
        switch self {
        case .half:
            "Half resolution"
        case .longEdge1080:
            "Max 1080p"
        case .longEdge720:
            "Max 720p"
        case .github10:
            "GitHub issue video - 10 MB"
        case .github100:
            "GitHub issue video - 100 MB"
        }
    }

    var suffix: String {
        switch self {
        case .half:
            "half"
        case .longEdge1080:
            "1080p"
        case .longEdge720:
            "720p"
        case .github10:
            "github-10mb"
        case .github100:
            "github-100mb"
        }
    }

    var needsTargetSize: Bool {
        switch self {
        case .github10, .github100:
            true
        case .half, .longEdge1080, .longEdge720:
            false
        }
    }

    var targetMegabytes: Double? {
        switch self {
        case .github10:
            9.5
        case .github100:
            95
        case .half, .longEdge1080, .longEdge720:
            nil
        }
    }

    var displayLimitMegabytes: Int? {
        switch self {
        case .github10:
            10
        case .github100:
            100
        case .half, .longEdge1080, .longEdge720:
            nil
        }
    }
}

@discardableResult
func run(_ command: String, _ arguments: [String], captureOutput: Bool = false) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [command] + arguments
    process.environment = processEnvironment()

    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error

    try process.run()
    process.waitUntilExit()

    let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
        let details = (errorText.isEmpty ? outputText : errorText).trimmingCharacters(in: .whitespacesAndNewlines)
        throw VRFailure.message(details.isEmpty ? "\(command) exited with \(process.terminationStatus)" : details)
    }

    return captureOutput ? outputText : ""
}

func processEnvironment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let fallbackPaths = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    let existingPath = environment["PATH"] ?? ""
    let paths = (existingPath.split(separator: ":").map(String.init) + fallbackPaths)
        .reduce(into: [String]()) { result, path in
            if !result.contains(path) {
                result.append(path)
            }
        }

    environment["PATH"] = paths.joined(separator: ":")
    return environment
}

func requireTool(_ name: String) throws {
    do {
        _ = try run("which", [name], captureOutput: true)
    } catch {
        throw VRFailure.message("Missing dependency: \(name). Install it with `brew install ffmpeg`, then rerun install.sh.")
    }
}

func probe(_ input: URL) throws -> VideoInfo {
    let json = try run(
        "ffprobe",
        [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,duration:format=duration",
            "-of", "json",
            input.path
        ],
        captureOutput: true
    )

    guard
        let data = json.data(using: .utf8),
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let streams = object["streams"] as? [[String: Any]],
        let stream = streams.first,
        let width = stream["width"] as? Int,
        let height = stream["height"] as? Int
    else {
        throw VRFailure.message("Could not read video dimensions for \(input.path)")
    }

    let rawStreamDuration = stream["duration"] as? String
    let format = object["format"] as? [String: Any]
    let rawFormatDuration = format?["duration"] as? String
    let duration = rawStreamDuration.flatMap(Double.init) ?? rawFormatDuration.flatMap(Double.init) ?? 0

    return VideoInfo(width: width, height: height, duration: duration)
}

func source(for inputPath: String) throws -> VideoSource {
    let input = URL(fileURLWithPath: inputPath)
    guard FileManager.default.fileExists(atPath: input.path) else {
        throw VRFailure.message("File does not exist: \(input.path)")
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: input.path)
    let size = attributes[.size] as? NSNumber
    return VideoSource(url: input, info: try probe(input), sizeBytes: size?.int64Value ?? 0)
}

func outputURL(for input: URL, preset: Preset) -> URL {
    let directory = input.deletingLastPathComponent()
    let base = input.deletingPathExtension().lastPathComponent
    var candidate = directory.appendingPathComponent("\(base)-\(preset.suffix).mp4")
    var index = 2

    while FileManager.default.fileExists(atPath: candidate.path) {
        candidate = directory.appendingPathComponent("\(base)-\(preset.suffix)-\(index).mp4")
        index += 1
    }

    return candidate
}

func scaleFilter(for preset: Preset) -> String? {
    switch preset {
    case .half:
        "scale=trunc(iw/4)*2:trunc(ih/4)*2"
    case .longEdge1080:
        "scale='if(gte(iw,ih),min(1920,iw),-2)':'if(gte(iw,ih),-2,min(1920,ih))'"
    case .longEdge720:
        "scale='if(gte(iw,ih),min(1280,iw),-2)':'if(gte(iw,ih),-2,min(1280,ih))'"
    case .github10, .github100:
        "scale='if(gte(iw,ih),min(1920,iw),-2)':'if(gte(iw,ih),-2,min(1920,ih))'"
    }
}

func scaledDimensions(for info: VideoInfo, preset: Preset) -> (width: Int, height: Int) {
    switch preset {
    case .half:
        return (max(2, (info.width / 2) / 2 * 2), max(2, (info.height / 2) / 2 * 2))
    case .longEdge1080, .github10, .github100:
        return dimensionsConstrainedToLongEdge(info: info, longEdge: 1920)
    case .longEdge720:
        return dimensionsConstrainedToLongEdge(info: info, longEdge: 1280)
    }
}

func dimensionsConstrainedToLongEdge(info: VideoInfo, longEdge: Int) -> (width: Int, height: Int) {
    let currentLongEdge = max(info.width, info.height)
    guard currentLongEdge > longEdge else {
        return (info.width, info.height)
    }

    let ratio = Double(longEdge) / Double(currentLongEdge)
    let width = max(2, Int((Double(info.width) * ratio).rounded()) / 2 * 2)
    let height = max(2, Int((Double(info.height) * ratio).rounded()) / 2 * 2)
    return (width, height)
}

func estimateBytes(for source: VideoSource, preset: Preset) -> ClosedRange<Int64> {
    if let targetMegabytes = preset.targetMegabytes {
        let targetBytes = Int64(targetMegabytes * 1_000_000)
        return targetBytes...targetBytes
    }

    let scaled = scaledDimensions(for: source.info, preset: preset)
    let originalPixels = max(1, source.info.width * source.info.height)
    let scaledPixels = max(1, scaled.width * scaled.height)
    let pixelRatio = Double(scaledPixels) / Double(originalPixels)

    let qualityFactor: Double
    switch pixelRatio {
    case ..<0.15:
        qualityFactor = 0.06
    case ..<0.35:
        qualityFactor = 0.12
    case ..<0.65:
        qualityFactor = 0.22
    default:
        qualityFactor = 0.35
    }

    let audioBytes = source.info.duration > 0 ? source.info.duration * 128_000 / 8 : 0
    let midpoint = max(64_000, (Double(source.sizeBytes) * pixelRatio * qualityFactor) + audioBytes)
    let lower = Int64(max(64_000, midpoint * 0.5))
    let upper = Int64(max(Double(lower), midpoint * 1.8))
    return lower...upper
}

func combinedEstimate(for sources: [VideoSource], preset: Preset) -> ClosedRange<Int64> {
    let ranges = sources.map { estimateBytes(for: $0, preset: preset) }
    let lower = ranges.reduce(Int64(0)) { $0 + $1.lowerBound }
    let upper = ranges.reduce(Int64(0)) { $0 + $1.upperBound }
    return lower...upper
}

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

func estimateLabel(for sources: [VideoSource], preset: Preset) -> String {
    if let limit = preset.displayLimitMegabytes {
        if sources.count == 1 {
            return "target <\(limit) MB"
        }

        let total = Int64((preset.targetMegabytes ?? Double(limit)) * 1_000_000 * Double(sources.count))
        return "target <\(limit) MB each, \(formatBytes(total)) total"
    }

    let estimate = combinedEstimate(for: sources, preset: preset)
    let prefix = sources.count == 1 ? "est." : "est. total"
    return "\(prefix) \(formatBytes(estimate.lowerBound))-\(formatBytes(estimate.upperBound))"
}

func resizeCRF(input: URL, output: URL, preset: Preset) throws {
    var args = ["-y", "-i", input.path]
    if let filter = scaleFilter(for: preset) {
        args += ["-vf", filter]
    }
    args += [
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "28",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "128k",
        "-movflags", "+faststart",
        output.path
    ]

    _ = try run("ffmpeg", args)
}

func resizeToTarget(input: URL, output: URL, preset: Preset) throws {
    let info = try probe(input)
    guard info.duration > 0 else {
        throw VRFailure.message("Could not read video duration for \(input.path)")
    }

    let targetMegabytes = preset.targetMegabytes ?? 9.5
    let targetBits = targetMegabytes * 1_000_000 * 8
    let audioBitsPerSecond = 96_000.0
    let safetyFactor = 0.92
    let videoBitsPerSecond = max(80_000, Int(((targetBits / info.duration) - audioBitsPerSecond) * safetyFactor))
    let bitrate = "\(videoBitsPerSecond)"

    let passlog = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("vr-\(UUID().uuidString)")
        .path

    defer {
        for suffix in ["-0.log", "-0.log.mbtree"] {
            try? FileManager.default.removeItem(atPath: passlog + suffix)
        }
    }

    let common = [
        "-y",
        "-i", input.path,
        "-vf", scaleFilter(for: preset) ?? "scale=iw:ih",
        "-c:v", "libx264",
        "-preset", "medium",
        "-b:v", bitrate,
        "-pix_fmt", "yuv420p",
        "-passlogfile", passlog
    ]

    _ = try run("ffmpeg", common + ["-pass", "1", "-an", "-f", "null", "/dev/null"])
    _ = try run(
        "ffmpeg",
        common + [
            "-pass", "2",
            "-c:a", "aac",
            "-b:a", "96k",
            "-movflags", "+faststart",
            output.path
        ]
    )
}

func resize(inputPath: String, preset: Preset) throws -> URL {
    let input = URL(fileURLWithPath: inputPath)
    guard FileManager.default.fileExists(atPath: input.path) else {
        throw VRFailure.message("File does not exist: \(input.path)")
    }

    let output = outputURL(for: input, preset: preset)
    if preset.needsTargetSize {
        try resizeToTarget(input: input, output: output, preset: preset)
    } else {
        try resizeCRF(input: input, output: output, preset: preset)
    }

    return output
}

func printHelp() {
    let presets = Preset.allCases.map { "  \($0.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0)) \($0.title)" }.joined(separator: "\n")
    print(
        """
        vr - video resizing utility

        Usage:
          vr --preset <preset> <video...>
          vr --dialog <video...>
          vr --estimate <video...>
          vr --list-presets

        Presets:
        \(presets)

        Examples:
          vr --preset half ~/Desktop/demo.mov
          vr --preset github-10mb ~/Desktop/demo.mp4
        """
    )
}

func showAlert(title: String, message: String, style: NSAlert.Style = .informational) {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func choosePreset(sources: [VideoSource]) -> Preset? {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.activate(ignoringOtherApps: true)

    let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 540, height: 28), pullsDown: false)
    for preset in Preset.allCases {
        popup.addItem(withTitle: "\(preset.title) - \(estimateLabel(for: sources, preset: preset))")
    }

    let alert = NSAlert()
    alert.messageText = sources.count == 1 ? "Resize Video" : "Resize \(sources.count) Videos"
    alert.informativeText = "Choose a resize option. Quality presets show estimated output size; GitHub presets show target size."
    alert.accessoryView = popup
    alert.addButton(withTitle: "Resize")
    alert.addButton(withTitle: "Cancel")

    guard alert.runModal() == .alertFirstButtonReturn else {
        return nil
    }

    return Preset.allCases[popup.indexOfSelectedItem]
}

func runDialog(paths: [String]) {
    guard !paths.isEmpty else {
        showAlert(title: "No Videos Selected", message: "Select one or more videos in Finder, then run VR Resize Video.", style: .warning)
        return
    }

    do {
        try requireTool("ffmpeg")
        try requireTool("ffprobe")

        let sources = try paths.map(source(for:))
        guard let preset = choosePreset(sources: sources) else {
            return
        }

        var outputs: [URL] = []
        for path in paths {
            outputs.append(try resize(inputPath: path, preset: preset))
        }

        let message = outputs.map(\.path).joined(separator: "\n")
        showAlert(title: "Resize Complete", message: message)
    } catch {
        showAlert(title: "Resize Failed", message: error.localizedDescription, style: .critical)
    }
}

func printEstimates(paths: [String]) throws {
    try requireTool("ffprobe")
    let sources = try paths.map(source(for:))
    for preset in Preset.allCases {
        print("\(preset.rawValue)\t\(estimateLabel(for: sources, preset: preset))")
    }
}

func runCLI(arguments: [String]) -> Int32 {
    do {
        guard let first = arguments.first else {
            printHelp()
            return 0
        }

        switch first {
        case "-h", "--help", "help":
            printHelp()
            return 0
        case "--list-presets":
            for preset in Preset.allCases {
                print("\(preset.rawValue)\t\(preset.title)")
            }
            return 0
        case "--dialog":
            runDialog(paths: Array(arguments.dropFirst()))
            return 0
        case "--estimate":
            guard arguments.count >= 2 else {
                throw VRFailure.message("Usage: vr --estimate <video...>")
            }
            try printEstimates(paths: Array(arguments.dropFirst()))
            return 0
        case "--preset":
            guard arguments.count >= 3 else {
                throw VRFailure.message("Usage: vr --preset <preset> <video...>")
            }
            guard let preset = Preset(rawValue: arguments[1]) else {
                throw VRFailure.message("Unknown preset: \(arguments[1])")
            }

            try requireTool("ffmpeg")
            try requireTool("ffprobe")

            for path in arguments.dropFirst(2) {
                let output = try resize(inputPath: path, preset: preset)
                print(output.path)
            }
            return 0
        default:
            throw VRFailure.message("Unknown command: \(first)")
        }
    } catch {
        FileHandle.standardError.write(Data("vr: \(error.localizedDescription)\n".utf8))
        return 1
    }
}

exit(runCLI(arguments: Array(CommandLine.arguments.dropFirst())))
