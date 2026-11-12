import Foundation

public enum BoardDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case rows, columns
    public var id: String { rawValue }
    public var title: String { self == .rows ? "Строки" : "Столбцы" }
}
public enum BoardPreferences {
    public static func style(boardID: UUID, isGeneral: Bool, space: String, defaults: UserDefaults = .standard)
        -> BoardDisplayStyle
    { defaults.string(forKey: key(boardID, space)).flatMap(BoardDisplayStyle.init) ?? (isGeneral ? .columns : .rows) }
    public static func save(
        _ style: BoardDisplayStyle, boardID: UUID, space: String, defaults: UserDefaults = .standard
    ) { defaults.set(style.rawValue, forKey: key(boardID, space)) }
    private static func key(_ id: UUID, _ space: String) -> String { "boardLayout:" + space + ":" + id.uuidString }
}
