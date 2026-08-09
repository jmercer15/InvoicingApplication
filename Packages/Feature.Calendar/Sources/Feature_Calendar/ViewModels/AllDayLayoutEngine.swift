struct AllDayPositionedItem: Identifiable {
    let id: String
    let item: DisplayableCalendarItem
    let startDayIndex: Int
    let endDayIndex: Int
    let rowIndex: Int
}
