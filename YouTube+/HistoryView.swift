import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchHistoryItem.watchedAt, order: .reverse) private var history: [WatchHistoryItem]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if history.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock").font(.system(size: 52)).foregroundColor(Theme.text3)
                        Text("История пуста").font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text2)
                    }
                } else {
                    List {
                        ForEach(history) { item in
                            historyRow(item)
                                .listRowBackground(Theme.bg)
                                .listRowSeparatorTint(Color.white.opacity(0.06))
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(history[$0]) }
                            try? context.save()
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("История")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bg2, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if !history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            history.forEach { context.delete($0) }
                            try? context.save()
                        } label: {
                            Text("Очистить").foregroundColor(Theme.accent).font(.system(size: 14))
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ item: WatchHistoryItem) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.thumbnailURL)) { img in
                img.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Theme.bg3)
            }
            .frame(width: 80, height: 48)
            .cornerRadius(10)
            .clipped()

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                Text(item.channelName)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text3)
                Text(item.watchedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text3)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
