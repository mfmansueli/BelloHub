//
//  PermissionServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@MainActor
@Suite("PermissionService")
struct PermissionServiceTests {
    @Test("Nothing is asked until it is asked, and an answer is remembered")
    func requests() async {
        let provider = FakePermissionProvider(answers: [.microphone: .granted, .camera: .denied])
        let service = PermissionService(provider: provider)
        #expect(service.status(of: .microphone) == .notDetermined)

        let microphone = await service.request(.microphone)
        let camera = await service.request(.camera)

        #expect(microphone == .granted && camera == .denied)
        #expect(service.status(of: .microphone) == .granted)
        #expect(service.status(of: .camera) == .denied)
        #expect(service.status(of: .contacts) == .notDetermined)
        #expect(provider.requested == [.microphone, .camera])
    }

    @Test("The permissions are asked in the order of the onboarding pages")
    func order() {
        #expect(PermissionKind.allCases == [.microphone, .notifications, .camera, .contacts])
    }
}
