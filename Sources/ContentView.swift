import SwiftUI
import FamilyControls

struct ContentView: View {
    @StateObject private var shield = ShieldManager()
    @StateObject private var nfc = NFCManager()
    @State private var showPicker = false
    @State private var statusText = "Not scanned yet"

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: shield.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 64))
                    .foregroundColor(shield.isLocked ? .red : .green)

                Text(shield.isLocked ? "Apps are locked" : "Apps are unlocked")
                    .font(.title2).bold()

                Text(nfc.trustedTagID == nil ? "No tag programmed yet" : "Tag registered ✓")
                    .foregroundColor(.secondary)

                Button {
                    showPicker = true
                } label: {
                    Label("Choose apps to block", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.bordered)
                .familyActivityPicker(
                    isPresented: $showPicker,
                    selection: Binding(
                        get: { shield.selection },
                        set: { shield.saveSelection($0) }
                    )
                )

                Button {
                    statusText = "Waiting for a blank tag…"
                    nfc.scanToProgram()
                } label: {
                    Label("Program a new tag", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .disabled(nfc.isBusy)

                Button {
                    statusText = "Waiting for your tag…"
                    nfc.scanToToggle()
                } label: {
                    Label("Tap tag to lock/unlock", systemImage: "wave.3.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(nfc.isBusy || nfc.trustedTagID == nil)

                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .padding()
            .navigationTitle("Brick Clone")
            .task {
                await shield.requestAuthorization()
            }
            .onAppear {
                nfc.onTagMatched = { _ in
                    shield.toggle()
                    statusText = shield.isLocked ? "Locked via tag" : "Unlocked via tag"
                }
                nfc.onUnrecognizedTag = {
                    statusText = "Unrecognized tag — ignored"
                }
                nfc.onTagWritten = { _ in
                    statusText = "Tag programmed and registered"
                }
                nfc.onError = { message in
                    statusText = message
                }
            }
        }
    }
}
