import Foundation

/// Sichert die App-Daten als Datei in iCloud Drive (Container der App, für den Nutzer unsichtbar).
/// Beim Start auf einem neuen Gerät wird die neuere Kopie übernommen.
enum CloudBackup {
    static let containerId = "iCloud.de.nicosellmaier.form"
    private static var pending: DispatchWorkItem?
    private static var cachedURL: URL??

    /// Datei im iCloud-Container, nil ohne iCloud-Anmeldung oder ohne Berechtigung
    static var fileURL: URL? {
        if let c = cachedURL { return c }
        let base = FileManager.default.url(forUbiquityContainerIdentifier: containerId)
        let docs = base?.appendingPathComponent("Documents", isDirectory: true)
        if let docs { try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true) }
        let u = docs?.appendingPathComponent("form-data.json")
        cachedURL = .some(u)
        return u
    }

    static var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil && fileURL != nil }

    /// Letzte Sicherung laut Datei
    static var lastBackup: Date? {
        guard let u = fileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: u.path) else { return nil }
        return attrs[.modificationDate] as? Date
    }

    static var size: Int {
        guard let u = fileURL, let attrs = try? FileManager.default.attributesOfItem(atPath: u.path) else { return 0 }
        return (attrs[.size] as? Int) ?? 0
    }

    static func read() -> AppData? {
        guard let u = fileURL else { return nil }
        if !FileManager.default.fileExists(atPath: u.path) {
            // Noch nicht heruntergeladen? Download anstoßen, beim nächsten Start ist sie da.
            try? FileManager.default.startDownloadingUbiquitousItem(at: u)
            return nil
        }
        var data: Data?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: u, options: [], error: nil) { url in data = try? Data(contentsOf: url) }
        guard let data else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(AppData.self, from: data)
    }

    /// Gesammelt schreiben: viele kleine Änderungen hintereinander ergeben einen Upload
    static func scheduleWrite(_ d: Data) {
        pending?.cancel()
        let w = DispatchWorkItem { write(d) }
        pending = w
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3, execute: w)
    }

    static func write(_ d: Data) {
        guard let u = fileURL else { return }
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: u, options: .forReplacing, error: nil) { url in
            try? d.write(to: url, options: .atomic)
        }
    }
}
