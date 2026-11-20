import AppKit

/// The meeting alert sound: a macOS sound name, or the full path of any audio file.
enum AlertSound {
    static let system = ["None", "Glass", "Ping", "Pop", "Purr", "Hero", "Submarine", "Tink", "Funk", "Blow", "Bottle", "Frog", "Morse", "Sosumi"]

    /// Where the file picker starts, so Notion Calendar's own sounds are one click away.
    static var notionCalendarResources: URL? {
        let resources = URL(fileURLWithPath: "/Applications/Notion Calendar.app/Contents/Resources")
        return FileManager.default.fileExists(atPath: resources.path) ? resources : nil
    }

    static func isFile(_ sound: String) -> Bool {
        sound.hasPrefix("/")
    }

    static func displayName(_ sound: String) -> String {
        isFile(sound) ? URL(fileURLWithPath: sound).deletingPathExtension().lastPathComponent : sound
    }

    static func play(_ sound: String) {
        guard sound != "None" else { return }
        let chosen = isFile(sound)
            ? NSSound(contentsOf: URL(fileURLWithPath: sound), byReference: true)
            : NSSound(named: NSSound.Name(sound))
        // Fall back to Glass if a chosen file was moved or deleted, so alerts never go silent.
        (chosen ?? NSSound(named: NSSound.Name("Glass")))?.play()
    }
}
