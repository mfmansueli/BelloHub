//
//  BookingSetupRepository.swift
//  BelloHub
//

import Foundation

/// How clients can book her: availability, the booking page switches, cancel and no-show policies and quick replies
/// (S5). Non-clinical, stored in the clear (docs/05-DATA-MODEL.md section 1). The booking slice of S5 fills this
/// protocol and both vault implementations, in their own files. Publishing to the server is `BookingRepository`'s
/// job (fake until S8), not this one's.
protocol BookingSetupRepository: Sendable {}
