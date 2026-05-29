// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Presents `NSOpenPanel` / `NSSavePanel` correctly from a module, working around the
/// two quirks of the host's window model that otherwise make file pickers misbehave.
///
/// **Why a module shouldn't roll its own `NSOpenPanel`.** The host is an agent app
/// (`LSUIElement`) whose only window is a `.nonactivatingPanel`. Clicking the notch
/// never activates the app — that is the point of a non-activating panel — so at the
/// moment a module asks for a file, the app is *inactive*. An `NSOpenPanel` presented
/// by an inactive agent app comes up non-key: it may appear behind the frontmost app
/// and its sidebar / navigation stop responding to clicks. The fix is to request app
/// activation immediately before presenting. Every module would otherwise have to
/// rediscover this; the host owns it once, here.
///
/// **Pinning.** A picker is a separate AppKit panel outside the notch window — the same
/// situation ``NookPresentationPinning`` exists for. While the panel is up the pointer
/// has left the notch, so without intervention the surface auto-compacts (taking nothing
/// visible with it, but dropping engagement) and a competing module's arbiter claim can
/// be granted underneath. The picker therefore holds a pin for the panel's entire
/// lifetime and releases it once the panel closes.
///
/// **Security scope.** A file the user picks comes back already security-scoped: the
/// system starts access on a panel-returned URL "as if you called
/// `startAccessingSecurityScopedResource()`". The returned ``NookFileSelection`` owns
/// that live access and balances it with a matching stop when it is released, so a
/// long-lived agent process doesn't leak kernel scope resources. Read the file's
/// contents (or capture a security-scoped bookmark) inside
/// ``NookFileSelection/withAccess(_:)``.
///
/// **Resolving.** The host registers one instance per process into every module's
/// ``AppServices``. A module reaches it through ``NookFilePickerKey``:
///
/// ```swift
/// @Environment(\.appServices) private var services
///
/// Button("Import") {
///     Task {
///         let picker = services.resolve(NookFilePickerKey.self)
///         guard let selection = await picker.open(.init(allowedContentTypes: [.pdf])) else { return }
///         selection.withAccess { urls in shelf.accept(urls) }
///     }
/// }
/// ```
///
/// > Note: only one panel is presented at a time. A call made while another panel is
/// > already open returns `nil` immediately rather than stacking a second picker.
@MainActor
public protocol NookFilePresenting {
    /// Presents an open panel and returns the user's selection, or `nil` if they
    /// cancelled (or a panel was already open). See ``NookOpenOptions``.
    func open(_ options: NookOpenOptions) async -> NookFileSelection?

    /// Presents a save panel and returns the chosen destination, or `nil` if they
    /// cancelled (or a panel was already open). See ``NookSaveOptions``.
    func save(_ options: NookSaveOptions) async -> NookFileSelection?
}

public extension NookFilePresenting {
    /// Convenience for presenting an open panel with default options.
    func open() async -> NookFileSelection? { await open(.init()) }

    /// Convenience for presenting a save panel with default options.
    func save() async -> NookFileSelection? { await save(.init()) }
}

// MARK: - Options

/// Configuration for an open panel. All fields default to a single-file picker.
public struct NookOpenOptions: Sendable {
    /// File types the user may pick. Empty means any type.
    public var allowedContentTypes: [UTType]
    /// Whether more than one item may be selected.
    public var allowsMultipleSelection: Bool
    /// Whether files are selectable.
    public var canChooseFiles: Bool
    /// Whether directories are selectable.
    public var canChooseDirectories: Bool
    /// Directory the panel opens to, or `nil` for the system default.
    public var directoryURL: URL?
    /// Label for the default button (e.g. "Import"). `nil` keeps the system default.
    public var prompt: String?
    /// Explanatory message shown above the browser. `nil` shows none.
    public var message: String?
    /// Window title. `nil` keeps the system default.
    public var title: String?

    public init(
        allowedContentTypes: [UTType] = [],
        allowsMultipleSelection: Bool = false,
        canChooseFiles: Bool = true,
        canChooseDirectories: Bool = false,
        directoryURL: URL? = nil,
        prompt: String? = nil,
        message: String? = nil,
        title: String? = nil
    ) {
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.canChooseFiles = canChooseFiles
        self.canChooseDirectories = canChooseDirectories
        self.directoryURL = directoryURL
        self.prompt = prompt
        self.message = message
        self.title = title
    }
}

/// Configuration for a save panel.
public struct NookSaveOptions: Sendable {
    /// Allowed file types for the saved document. Empty means any type.
    public var allowedContentTypes: [UTType]
    /// Pre-filled file name (without requiring an extension). `nil` leaves it empty.
    public var nameFieldStringValue: String?
    /// Directory the panel opens to, or `nil` for the system default.
    public var directoryURL: URL?
    /// Whether the user may create new directories from the panel.
    public var canCreateDirectories: Bool
    /// Label for the default button (e.g. "Export"). `nil` keeps the system default.
    public var prompt: String?
    /// Explanatory message shown above the browser. `nil` shows none.
    public var message: String?
    /// Window title. `nil` keeps the system default.
    public var title: String?

    public init(
        allowedContentTypes: [UTType] = [],
        nameFieldStringValue: String? = nil,
        directoryURL: URL? = nil,
        canCreateDirectories: Bool = true,
        prompt: String? = nil,
        message: String? = nil,
        title: String? = nil
    ) {
        self.allowedContentTypes = allowedContentTypes
        self.nameFieldStringValue = nameFieldStringValue
        self.directoryURL = directoryURL
        self.canCreateDirectories = canCreateDirectories
        self.prompt = prompt
        self.message = message
        self.title = title
    }
}

// MARK: - Selection

/// The user's picker selection, owning the live security-scoped access the system
/// granted for the picked URLs.
///
/// The system starts security-scoped access on panel-returned URLs implicitly. This
/// type balances that grant: it stops access for each URL when it is released
/// (`deinit`), so a long-running process doesn't leak the scope. Do content reads —
/// or capture a `.withSecurityScope` bookmark to persist access across launches —
/// while the selection is alive, ideally inside ``withAccess(_:)``. After the selection
/// is released the URLs are path-level only and reads will fail under the sandbox.
public final class NookFileSelection: Sendable {
    /// The picked URLs, in selection order. For a save panel this holds the single
    /// destination URL.
    public let urls: [URL]

    /// The first (or only) picked URL — convenient for the save / single-file case.
    public var url: URL? { urls.first }

    init(urls: [URL]) {
        self.urls = urls
    }

    /// Runs `body` while the selection's security-scoped access is live, returning its
    /// result. The access is already active for the selection's lifetime; this method is
    /// the recommended bracket for reads and bookmark capture so the intent — "use the
    /// files now, while you're allowed to" — is explicit at the call site.
    @discardableResult
    public func withAccess<T>(_ body: ([URL]) throws -> T) rethrows -> T {
        try body(urls)
    }

    deinit {
        // Balance the implicit start the system performed on each panel-returned URL.
        // Safe off the main actor (these are Foundation URL methods, not actor state)
        // and a no-op for an unsandboxed process where access was never scoped.
        for url in urls {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

// MARK: - Picker

/// Host-owned file picker. One instance per process, shared across modules; see
/// ``NookFilePresenting`` for the rationale, scope contract, and usage.
@MainActor
public final class NookFilePicker: NookFilePresenting {
    private let presentationPinning: NookPresentationPinning

    /// The panel currently on screen, if any. Held so a cancelled task can dismiss it.
    private var activePanel: NSSavePanel?

    /// Guards against stacking a second panel while one is already up.
    private var isPresenting = false

    public init(presentationPinning: NookPresentationPinning) {
        self.presentationPinning = presentationPinning
    }

    public func open(_ options: NookOpenOptions = .init()) async -> NookFileSelection? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = options.canChooseFiles
        panel.canChooseDirectories = options.canChooseDirectories
        panel.allowsMultipleSelection = options.allowsMultipleSelection
        if !options.allowedContentTypes.isEmpty {
            panel.allowedContentTypes = options.allowedContentTypes
        }
        configureCommon(
            panel,
            directoryURL: options.directoryURL,
            prompt: options.prompt,
            message: options.message,
            title: options.title
        )
        let urls = await present(panel)
        return urls.isEmpty ? nil : NookFileSelection(urls: urls)
    }

    public func save(_ options: NookSaveOptions = .init()) async -> NookFileSelection? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = options.canCreateDirectories
        if !options.allowedContentTypes.isEmpty {
            panel.allowedContentTypes = options.allowedContentTypes
        }
        if let name = options.nameFieldStringValue {
            panel.nameFieldStringValue = name
        }
        configureCommon(
            panel,
            directoryURL: options.directoryURL,
            prompt: options.prompt,
            message: options.message,
            title: options.title
        )
        let urls = await present(panel)
        return urls.isEmpty ? nil : NookFileSelection(urls: urls)
    }

    private func configureCommon(
        _ panel: NSSavePanel,
        directoryURL: URL?,
        prompt: String?,
        message: String?,
        title: String?
    ) {
        if let directoryURL { panel.directoryURL = directoryURL }
        if let prompt { panel.prompt = prompt }
        if let message { panel.message = message }
        if let title { panel.title = title }
    }

    /// Presents `panel` and resolves to the selected URLs (empty on cancel, rejection,
    /// or task cancellation). `NSOpenPanel` is an `NSSavePanel` subclass, so this one
    /// path serves both.
    private func present(_ panel: NSSavePanel) async -> [URL] {
        guard !isPresenting else { return [] }
        isPresenting = true
        activePanel = panel
        defer {
            isPresenting = false
            activePanel = nil
        }

        // Hold the surface engaged for the panel's whole lifetime: the `defer` runs only
        // after the continuation below resumes, i.e. after the panel has closed.
        let pin = presentationPinning.pin(reason: "file-picker")
        defer { pin.release() }

        // Request activation so the panel comes up key and interactive despite the host
        // being an inactive agent app behind a non-activating panel. `activate()` is the
        // non-deprecated form; it is honored because this call chains from a user action.
        NSApp.activate()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<[URL], Never>) in
                // If the surrounding task was already cancelled, don't even show the
                // panel — resume empty. `begin` is never called, so there is exactly one
                // resume on this path.
                if Task.isCancelled {
                    continuation.resume(returning: [])
                    return
                }
                panel.begin { response in
                    continuation.resume(returning: Self.selectedURLs(from: panel, response: response))
                }
            }
        } onCancel: {
            // Task cancelled (e.g. the presenting view went away). Dismiss the panel;
            // that routes through `begin`'s single completion with `.cancel`, which is
            // the only place the continuation resumes — so no double-resume.
            Task { @MainActor [weak self] in
                self?.activePanel?.cancel(nil)
            }
        }
    }

    private static func selectedURLs(
        from panel: NSSavePanel,
        response: NSApplication.ModalResponse
    ) -> [URL] {
        guard response == .OK else { return [] }
        if let open = panel as? NSOpenPanel {
            return open.urls
        }
        return panel.url.map { [$0] } ?? []
    }
}

// MARK: - Service key

/// Resolves the host's shared ``NookFilePicker`` from a module's ``AppServices``.
///
/// The host registers the live picker into every module's services as their contexts
/// are built. The `defaultValue` is a deliberately inert picker: resolving this key
/// without going through the host registry is a programming error (it traps in debug),
/// and in release it simply returns `nil` rather than presenting a panel that could
/// never hold the surface. Module tests can register their own ``NookFilePresenting``
/// fake against this key, since `NSOpenPanel` cannot run headless.
public struct NookFilePickerKey: ServiceKey {
    public static let defaultValue: any NookFilePresenting = UnregisteredFilePicker()
}

/// Inert stand-in used as ``NookFilePickerKey``'s default. Never presents anything.
private struct UnregisteredFilePicker: NookFilePresenting {
    init() {}

    func open(_ options: NookOpenOptions) async -> NookFileSelection? {
        assertionFailure(
            "NookFilePicker resolved without host registration — resolve NookFilePickerKey "
                + "from a module's AppServices (it is registered by the host)."
        )
        return nil
    }

    func save(_ options: NookSaveOptions) async -> NookFileSelection? {
        assertionFailure(
            "NookFilePicker resolved without host registration — resolve NookFilePickerKey "
                + "from a module's AppServices (it is registered by the host)."
        )
        return nil
    }
}
