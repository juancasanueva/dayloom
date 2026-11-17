import Foundation
import SwiftData

/// Folds together records that sync can duplicate, since CloudKit-backed stores can't
/// enforce uniqueness. The oldest record survives, so every Mac picks the same one.
///
/// Same-day habit completions are left alone: copies carry nothing that lets every Mac pick
/// the same survivor, so deleting them could remove a different copy on each Mac and lose the
/// tick. Every reading counts the day once, and un-ticking removes all copies.
struct DuplicateMerger {
    struct Report: Equatable {
        var tags = 0
        var dailyNotes = 0
    }

    /// Merges duplicates and returns how many records were removed of each kind.
    @discardableResult
    func mergeDuplicates(in context: ModelContext) -> Report {
        Report(
            tags: mergeTags(in: context),
            dailyNotes: mergeDailyNotes(in: context)
        )
    }

    // MARK: Tags

    /// Tags whose names match ignoring case and surrounding spaces become one.
    private func mergeTags(in context: ModelContext) -> Int {
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        let groups = Dictionary(grouping: tags) {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        var removed = 0
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted {
                ($0.createdAt, $0.mergeKey, $0.name, $0.colorRaw) < ($1.createdAt, $1.mergeKey, $1.name, $1.colorRaw)
            }
            let survivor = ordered[0]
            for duplicate in ordered.dropFirst() {
                for task in duplicate.tasks ?? [] {
                    var taskTags = (task.tags ?? []).filter { $0 !== duplicate }
                    if !taskTags.contains(where: { $0 === survivor }) {
                        taskTags.append(survivor)
                    }
                    task.tags = taskTags
                }
                context.delete(duplicate)
                removed += 1
            }
        }
        return removed
    }

    // MARK: Daily notes

    /// Daily notes for the same stored day become one; the copies' non-empty blocks are appended in order.
    /// The stored day start is compared exactly: a note made in another time zone starts its day at a
    /// different instant and is a different day, even if it falls on this Mac's local day.
    private func mergeDailyNotes(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.dailyDate != nil })
        let notes = (try? context.fetch(descriptor)) ?? []
        let groups = Dictionary(grouping: notes) { $0.dailyDate ?? .distantPast }
        var removed = 0
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted { ($0.createdAt, $0.mergeKey, $0.title) < ($1.createdAt, $1.mergeKey, $1.title) }
            let survivor = ordered[0]
            for duplicate in ordered.dropFirst() {
                for block in duplicate.orderedBlocks where !isBlank(block) {
                    // Detach first so deleting the copy doesn't cascade to the moved block.
                    duplicate.blocks?.removeAll { $0 === block }
                    block.sortIndex = (survivor.orderedBlocks.last?.sortIndex ?? 0) + 1
                    block.note = survivor
                }
                survivor.isPinned = survivor.isPinned || duplicate.isPinned
                survivor.updatedAt = max(survivor.updatedAt, duplicate.updatedAt)
                context.delete(duplicate)
                removed += 1
            }
        }
        return removed
    }

    private func isBlank(_ block: NoteBlock) -> Bool {
        block.kind == .text && block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
