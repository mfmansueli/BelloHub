//
//  UITestNotificationPoster.swift
//  BelloHub
//

#if DEBUG
/// A UI-test launch raises no notification on the simulator: the inbox itself shows what arrived.
struct UITestNotificationPoster: ImmediateNotifying {
    func post(id: String, threadID: String, title: String, body: String) async {}
}
#endif
