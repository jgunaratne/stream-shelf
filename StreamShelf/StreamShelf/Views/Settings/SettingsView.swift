import SwiftUI

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                connectionSection
                if !vm.sections.isEmpty {
                    librarySection
                }
                if let err = vm.errorMessage {
                    errorSection(err)
                }
            }
            .scrollContentBackground(.hidden)
            .background(StreamShelfTheme.Colors.appBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(StreamShelfTheme.Colors.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!vm.canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var serverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField("https://media.example.com:32400", text: $vm.baseURL)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: vm.baseURL) { _, _ in resetStatus() }
                Text("Base URL of your Plex server")
                    .font(.caption)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
                if let message = vm.baseURLValidationMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(StreamShelfTheme.Colors.destructive)
                }
                if let message = vm.baseURLSecurityMessage {
                    Label(message, systemImage: "lock.open")
                        .font(.caption)
                        .foregroundStyle(StreamShelfTheme.Colors.warning)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                SecureField("X-Plex-Token", text: $vm.token)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: vm.token) { _, _ in resetStatus() }
                Text("Stored securely in Keychain on this device")
                    .font(.caption)
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }
        } header: {
            Text("Server")
        }
    }

    private var connectionSection: some View {
        Section {
            Button {
                Task { await vm.loadSections() }
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    connectionStatusView
                }
            }
            .disabled(vm.connectionStatus.isLoading || !vm.canSave)
        } footer: {
            switch vm.connectionStatus {
            case .success(let count):
                Text("Connected — \(count) library section\(count == 1 ? "" : "s") found.")
                    .foregroundStyle(StreamShelfTheme.Colors.success)
            case .idle, .testing, .failure:
                Text("Test before saving to verify the server address and token.")
                    .foregroundStyle(StreamShelfTheme.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch vm.connectionStatus {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
                .tint(StreamShelfTheme.Colors.accent)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(StreamShelfTheme.Colors.success)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(StreamShelfTheme.Colors.destructive)
        }
    }

    private var librarySection: some View {
        Section("Default Library") {
            Picker("Section", selection: $vm.selectedSectionKey) {
                Text("None").tag("")
                ForEach(vm.sections.filter(\.isVideoSection)) { section in
                    Text("\(section.title) (\(section.type.capitalized))")
                        .tag(section.key)
                }
            }
            .pickerStyle(.inline)
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(StreamShelfTheme.Colors.destructive)
        }
    }

    private func resetStatus() {
        if case .idle = vm.connectionStatus { return }
        vm.connectionStatus = .idle
        vm.sections = []
    }
}

#Preview {
    SettingsView()
}
