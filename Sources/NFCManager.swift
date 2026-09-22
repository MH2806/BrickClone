import Foundation
import CoreNFC

final class NFCManager: NSObject, ObservableObject {
    @Published var isBusy = false

    var onTagMatched: ((String) -> Void)?
    var onUnrecognizedTag: (() -> Void)?
    var onTagWritten: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var session: NFCNDEFReaderSession?
    private var mode: Mode = .read
    private var pendingWriteID = ""

    private enum Mode { case read, write }

    private let trustedTagKey = "brickclone.trustedTagID"

    var trustedTagID: String? {
        get { UserDefaults.standard.string(forKey: trustedTagKey) }
        set { UserDefaults.standard.set(newValue, forKey: trustedTagKey) }
    }

    /// Scan a tag and toggle the shield if it matches the registered tag.
    func scanToToggle() {
        mode = .read
        beginSession(alertMessage: "Hold your iPhone near the Brick tag")
    }

    /// Scan a blank tag and write a fresh ID to it, registering it as the trusted tag.
    func scanToProgram() {
        mode = .write
        pendingWriteID = UUID().uuidString
        beginSession(alertMessage: "Hold your iPhone near a blank NFC tag to program it")
    }

    private func beginSession(alertMessage: String) {
        guard NFCNDEFReaderSession.readingAvailable else {
            onError?("This device doesn't support NFC scanning.")
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = alertMessage
        session?.begin()
        isBusy = true
    }
}

extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { self.isBusy = false }
    }

    // Required by the protocol; actual work happens in the tag-aware delegate method below.
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            switch self.mode {
            case .read:
                self.readTag(tag, session: session)
            case .write:
                self.writeTag(tag, session: session)
            }
        }
    }

    private func readTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { message, error in
            defer { DispatchQueue.main.async { self.isBusy = false } }

            guard let message = message,
                  let record = message.records.first,
                  let text = Self.decodeTextRecord(record) else {
                session.invalidate(errorMessage: "Couldn't read an ID from this tag.")
                return
            }

            session.alertMessage = "Tag detected"
            session.invalidate()

            DispatchQueue.main.async {
                if text == self.trustedTagID {
                    self.onTagMatched?(text)
                } else {
                    self.onUnrecognizedTag?()
                }
            }
        }
    }

    private func writeTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        let id = pendingWriteID
        guard let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: id, locale: Locale(identifier: "en")) else {
            session.invalidate(errorMessage: "Failed to build tag payload.")
            return
        }
        let message = NFCNDEFMessage(records: [payload])

        tag.queryNDEFStatus { status, _, error in
            guard error == nil, status == .readWrite else {
                session.invalidate(errorMessage: "This tag isn't writable (or is locked). Try a blank NTAG213/215 tag.")
                DispatchQueue.main.async { self.isBusy = false }
                return
            }

            tag.writeNDEF(message) { error in
                defer { DispatchQueue.main.async { self.isBusy = false } }
                if let error = error {
                    session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                    return
                }
                session.alertMessage = "Tag programmed"
                session.invalidate()
                DispatchQueue.main.async {
                    self.trustedTagID = id
                    self.onTagWritten?(id)
                }
            }
        }
    }

    /// NDEF text records store a status byte + language code before the actual text.
    private static func decodeTextRecord(_ record: NFCNDEFPayload) -> String? {
        guard let statusByte = record.payload.first else { return nil }
        let languageCodeLength = Int(statusByte & 0x3F)
        let textStart = 1 + languageCodeLength
        guard record.payload.count > textStart else { return nil }
        return String(data: record.payload.suffix(from: textStart), encoding: .utf8)
    }
}
