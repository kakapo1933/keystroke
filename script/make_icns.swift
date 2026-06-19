import Foundation

struct IconEntry {
    let tag: String
    let filename: String
}

let entries = [
    IconEntry(tag: "icp4", filename: "icon_16x16.png"),
    IconEntry(tag: "icp5", filename: "icon_32x32.png"),
    IconEntry(tag: "icp6", filename: "icon_32x32@2x.png"),
    IconEntry(tag: "ic07", filename: "icon_128x128.png"),
    IconEntry(tag: "ic08", filename: "icon_256x256.png"),
    IconEntry(tag: "ic09", filename: "icon_512x512.png"),
    IconEntry(tag: "ic10", filename: "icon_512x512@2x.png")
]

guard CommandLine.arguments.count == 3 else {
    fputs("usage: make_icns.swift <iconset-dir> <output.icns>\n", stderr)
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

func bigEndianData(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}

func tagData(_ tag: String) -> Data {
    guard let data = tag.data(using: .ascii), data.count == 4 else {
        fputs("invalid icns tag: \(tag)\n", stderr)
        exit(1)
    }
    return data
}

var chunks = Data()
for entry in entries {
    let fileURL = iconsetURL.appendingPathComponent(entry.filename)
    let pngData = try Data(contentsOf: fileURL)
    let chunkLength = UInt32(8 + pngData.count)

    chunks.append(tagData(entry.tag))
    chunks.append(bigEndianData(chunkLength))
    chunks.append(pngData)
}

let totalLength = UInt32(8 + chunks.count)
var output = Data()
output.append(tagData("icns"))
output.append(bigEndianData(totalLength))
output.append(chunks)

try output.write(to: outputURL, options: .atomic)
print("Generated \(outputURL.path)")
