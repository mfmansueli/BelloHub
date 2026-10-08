//
//  CalendarView.swift
//  BelloHub
//

import SwiftUI

/// 2.3 Calendar. The day and week views arrive in S6; until then the tab shows an honest empty state.
struct CalendarView: View {
    var body: some View {
        EmptyState(icon: .calendar, title: "calendar.empty.title", message: "calendar.empty.message")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
            .navigationTitle(Text("main.tab.calendar"))
            .accessibilityIdentifier("calendar.empty")
    }
}

#Preview {
    NavigationStack { CalendarView() }
}
