import Foundation
import SwiftData

@Model
final class Prompt {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var content: String
    var createdDate: Date
    var updatedDate: Date
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        content: String,
        createdDate: Date = .now,
        updatedDate: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.content = content
        self.createdDate = createdDate
        self.updatedDate = updatedDate ?? createdDate
        self.isFavorite = isFavorite
    }
}
