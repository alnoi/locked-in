struct NavigationHistory<Selection: Hashable> {
  private var selections: [Selection]
  private var switching: [Selection]?
  private var index = 0
  var current: Selection { switching?[index] ?? selections[0] }

  init(initial: Selection) { selections = [initial] }

  mutating func visit(_ selection: Selection) {
    guard selection != current else { return }
    finishSwitching()
    selections.removeAll { $0 == selection }
    selections.insert(selection, at: 0)
  }

  mutating func previous() -> Selection? {
    guard selections.count > 1 else { return nil }
    if switching == nil { switching = selections; index = 0 }
    index = (index + 1) % selections.count
    return current
  }

  mutating func finishSwitching() {
    guard switching != nil else { return }
    let selected = current
    switching = nil
    index = 0
    selections.removeAll { $0 == selected }
    selections.insert(selected, at: 0)
  }
}
