import AppKit
import GipherCore
import SwiftUI

struct SearchView: View {
    @ObservedObject var model: SearchModel
    @ObservedObject var settings: AppSettings
    @FocusState private var searchFocused: Bool
    @Namespace private var tabPill

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 8), count: SearchModel.columns)

    var body: some View {
        VStack(spacing: 0) {
            header
            if !model.suggestions.isEmpty { suggestionBar }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background(Theme.backdrop)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelRadius)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .tint(Theme.gold)
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                TextField("Search GIPHY", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium))
                    .focused($searchFocused)
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else if !model.query.isEmpty {
                    Button {
                        model.search("")
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help("Clear")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11).strokeBorder(Color.white.opacity(0.08))
            )
            tabs
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(WindowDragHandle())
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(SearchModel.Tab.allCases) { tab in
                let selected = model.tab == tab
                Button {
                    withAnimation(.snappy(duration: 0.2)) { model.tab = tab }
                } label: {
                    Text(tab.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? Theme.navy : Color.white.opacity(0.7))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                Capsule().fill(Theme.gold)
                                    .matchedGeometryEffect(id: "pill", in: tabPill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.09), in: Capsule())
    }

    // MARK: Suggestions

    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: model.trimmedQuery.isEmpty ? "flame.fill" : "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .help(model.trimmedQuery.isEmpty ? "Trending searches" : "Suggested searches")
                ForEach(model.suggestions, id: \.self) { term in
                    SuggestionChip(term: term) {
                        model.search(term)
                        searchFocused = true
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if settings.apiKey.isEmpty && model.tab != .recent {
            KeySetupView(settings: settings) { model.reload() }
        } else if !model.items.isEmpty {
            grid
        } else if model.isLoading {
            skeleton
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            if let message = model.message {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.gold)
                Text(message)
            } else if model.tab == .recent {
                Wordmark(size: 26)
                Text(model.query.isEmpty
                    ? "GIFs you send will show up here.\n\(Theme.tagline)"
                    : "No recent GIFs match “\(model.trimmedQuery)”.")
            } else {
                Text("Fumble.").font(.system(size: 26, weight: .black, design: .rounded)).italic()
                    .foregroundStyle(Theme.gold)
                Text("Nothing on GIPHY for “\(model.trimmedQuery)”.")
            }
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding()
    }

    private var skeleton: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: GifCell.height)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .frame(maxHeight: .infinity, alignment: .top)
        .phaseAnimator([0.45, 1.0]) { view, opacity in
            view.opacity(opacity)
        } animation: { _ in .easeInOut(duration: 0.7) }
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, gif in
                        GifCell(
                            gif: gif,
                            fit: model.tab == .stickers,
                            selected: model.selection == index,
                            sending: model.sendingID == gif.id
                        )
                        .id(gif.id)
                        .onTapGesture { model.onSend?(gif) }
                        .onDrag {
                            Paster.dragProvider(for: gif, quality: settings.sendQuality)
                        }
                        .contextMenu {
                            Button("Paste") { model.onSend?(gif) }
                            Button("Copy GIF") { model.onCopyOnly?(gif) }
                            if let page = gif.url {
                                Button("Copy GIPHY Link") { Paster.copy(text: page.absoluteString) }
                                Button("Open on GIPHY") { NSWorkspace.shared.open(page) }
                            }
                        }
                        .onAppear { model.loadMoreIfNeeded(index: index) }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 12)
            }
            .onChange(of: model.selection) { _, selection in
                guard let selection, model.items.indices.contains(selection) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(model.items[selection].id)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Wordmark()
            if let message = model.message, !model.items.isEmpty {
                Text(message).foregroundStyle(Theme.gold)
            } else {
                hint("↩", "paste")
                hint("↓", "browse")
                hint("tab", "complete")
                hint("drag", "drop anywhere")
                hint("esc", "close")
            }
            Spacer()
            Text("Powered by GIPHY")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.22))
        .background(WindowDragHandle())
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Keycap(key: key)
            Text(label)
        }
    }
}

private struct SuggestionChip: View {
    let term: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(term)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? Theme.navy : Color.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(hovering ? Theme.gold : Color.white.opacity(0.10), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

private struct GifCell: View {
    static let height: CGFloat = 116

    let gif: Gif
    let fit: Bool
    let selected: Bool
    let sending: Bool
    @State private var image: NSImage?
    @State private var hovering = false

    private var lifted: Bool { selected || hovering }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.opacity(0.07)
                if let image {
                    let size = imageSize(in: geo.size, image: image)
                    AnimatedImageView(image: image)
                        .frame(width: size.width, height: size.height)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                if sending {
                    Color.black.opacity(0.5)
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    selected ? Theme.gold : Color.white.opacity(hovering ? 0.55 : 0),
                    lineWidth: selected ? 3 : 2)
        )
        .shadow(color: .black.opacity(lifted ? 0.45 : 0), radius: 8, y: 4)
        .scaleEffect(lifted ? 1.04 : 1)
        .zIndex(lifted ? 1 : 0)
        .animation(.snappy(duration: 0.16), value: lifted)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help(gif.title)
        .accessibilityLabel(gif.title.isEmpty ? "GIF" : gif.title)
        .task(id: gif.id) {
            guard let url = gif.preview?.url, let data = await ImageLoader.shared.data(for: url)
            else { return }
            withAnimation(.easeOut(duration: 0.2)) { image = NSImage(data: data) }
        }
    }

    /// Fill the cell (cropping overflow) for GIFs; fit inside it for transparent stickers.
    private func imageSize(in cell: CGSize, image: NSImage) -> CGSize {
        let fallback = image.size.height > 0 ? image.size.width / image.size.height : 1
        let aspect = gif.preview?.aspectRatio ?? fallback
        let cellAspect = cell.width / max(cell.height, 1)
        let matchWidth = fit ? aspect > cellAspect : aspect < cellAspect
        return matchWidth
            ? CGSize(width: cell.width, height: cell.width / aspect)
            : CGSize(width: cell.height * aspect, height: cell.height)
    }
}

struct KeySetupView: View {
    @ObservedObject var settings: AppSettings
    var onSave: () -> Void = {}
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Wordmark(size: 40)
                Text(Theme.tagline)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text("One-time setup: TheGipher searches GIPHY with your own free API key.\nCreate an app at the GIPHY developer dashboard, choose “API”, and paste the key here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("Open developers.giphy.com/dashboard",
                 destination: URL(string: "https://developers.giphy.com/dashboard/")!)
                .foregroundStyle(Theme.gold)
            HStack {
                TextField("GIPHY API key", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .onSubmit(save)
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Theme.navy)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
    }

    private func save() {
        let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        settings.apiKey = key
        onSave()
    }
}
