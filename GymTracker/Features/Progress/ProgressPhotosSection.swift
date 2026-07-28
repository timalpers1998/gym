import SwiftUI
import SwiftData
import PhotosUI

/// "Progress Photos" section for the Progress tab: thumbnail strip, photo
/// import from the library, and a paging full-screen viewer.
struct ProgressPhotosSection: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \ProgressPhoto.date, order: .reverse)
    private var photos: [ProgressPhoto]

    @State private var pickerItem: PhotosPickerItem?
    @State private var viewerPhoto: ProgressPhoto?
    @State private var importFailed = false

    var body: some View {
        Section {
            if photos.isEmpty {
                Text("Add a photo every few weeks — progress you can't see on the scale.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(photos) { photo in
                            thumbnail(photo)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Add Photo", systemImage: "photo.badge.plus")
                    .font(.subheadline)
            }
        } header: {
            Text("Progress Photos")
        } footer: {
            if !photos.isEmpty {
                Text("Photos stay on this device and are not part of the JSON backup.")
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await importPhoto(newItem)
                pickerItem = nil
            }
        }
        .sheet(item: $viewerPhoto) { photo in
            PhotoViewer(initialPhoto: photo)
        }
        .alert("Couldn't Add Photo", isPresented: $importFailed) {
            Button("OK") {}
        } message: {
            Text("The selected image could not be read.")
        }
    }

    private func thumbnail(_ photo: ProgressPhoto) -> some View {
        Button {
            viewerPhoto = photo
        } label: {
            Group {
                if let image = PhotoStore.thumbnail(photo.fileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) {
                Text(photo.date.formatted(.dateTime.day().month()))
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.45))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let fileName = try? PhotoStore.save(data) else {
            importFailed = true
            return
        }
        let photo = ProgressPhoto(date: .now, fileName: fileName)
        context.insert(photo)
        try? context.save()
    }
}

/// Full-screen paging viewer, newest photo first.
private struct PhotoViewer: View {
    let initialPhoto: ProgressPhoto

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \ProgressPhoto.date, order: .reverse)
    private var photos: [ProgressPhoto]

    @State private var selection: PersistentIdentifier?
    @State private var showingDeleteConfirmation = false

    private var currentPhoto: ProgressPhoto? {
        photos.first { $0.persistentModelID == selection }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    Group {
                        if let image = PhotoStore.loadImage(photo.fileName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ContentUnavailableView(
                                "Photo Missing",
                                systemImage: "photo",
                                description: Text("The image file could not be found.")
                            )
                        }
                    }
                    .tag(Optional(photo.persistentModelID))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .background(.black)
            .navigationTitle(
                currentPhoto?.date.formatted(.dateTime.day().month().year()) ?? "Photo"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(currentPhoto == nil)
                }
            }
            .confirmationDialog(
                "Delete this photo?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Photo", role: .destructive) {
                    deleteCurrent()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                selection = initialPhoto.persistentModelID
            }
        }
    }

    private func deleteCurrent() {
        guard let photo = currentPhoto else { return }
        // The @Query only refreshes on the next view update — compute the
        // survivors first, or the checks below act on stale data.
        let deletedIndex = photos.firstIndex { $0.persistentModelID == photo.persistentModelID }
        let remaining = photos.filter { $0.persistentModelID != photo.persistentModelID }
        PhotoStore.delete(photo.fileName)
        context.delete(photo)
        try? context.save()
        guard !remaining.isEmpty else {
            dismiss()
            return
        }
        let neighbor = min(deletedIndex ?? 0, remaining.count - 1)
        selection = remaining[neighbor].persistentModelID
    }
}
