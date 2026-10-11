// Every callable use case, in one list. `index.ts` exports each as a deployed function; the contract tests check this
// list against API.md and against the exports, so a function cannot exist without being documented (and vice versa).

import { acknowledgeMailboxItem } from '../owner/acknowledgeMailboxItem.js';
import { cancelBookingByOwner } from '../owner/cancelBookingByOwner.js';
import { claimSlug } from '../owner/claimSlug.js';
import { deleteAccount } from '../owner/deleteAccount.js';
import { deleteClientServerData } from '../owner/deleteClientServerData.js';
import { ensureAccount } from '../owner/ensureAccount.js';
import { getMailboxItem } from '../owner/getMailboxItem.js';
import { isSlugAvailable } from '../owner/isSlugAvailable.js';
import { markNoShow } from '../owner/markNoShow.js';
import { moveBookingByOwner } from '../owner/moveBookingByOwner.js';
import { offerWaitlistSlot } from '../owner/offerWaitlistSlot.js';
import { publishAvailability } from '../owner/publishAvailability.js';
import { publishPortal } from '../owner/publishPortal.js';
import { publishProfile } from '../owner/publishProfile.js';
import { registerDevice } from '../owner/registerDevice.js';
import { removeWaitlistEntry } from '../owner/removeWaitlistEntry.js';
import { reserveRegistration } from '../owner/reserveRegistration.js';
import { reserveRegistrations } from '../owner/reserveRegistrations.js';
import { respondBookingRequest } from '../owner/respondBookingRequest.js';
import { respondRescheduleRequest } from '../owner/respondRescheduleRequest.js';
import { setOnlineBookingStopped } from '../owner/setOnlineBookingStopped.js';
import { mintManageLink } from '../owner/mintManageLink.js';
import { suggestBookingTime } from '../owner/suggestBookingTime.js';
import { syncPlan } from '../owner/syncPlan.js';
import { unregisterDevice } from '../owner/unregisterDevice.js';
import { updateInboxKey } from '../owner/updateInboxKey.js';
import { createBooking } from '../public/createBooking.js';
import { findBookings } from '../public/findBookings.js';
import { forgetDevice } from '../public/forgetDevice.js';
import { getFormContext } from '../public/getFormContext.js';
import { getHold } from '../public/getHold.js';
import { getPortal } from '../public/getPortal.js';
import { getPublicPage } from '../public/getPublicPage.js';
import { getSlots } from '../public/getSlots.js';
import { holdSlot } from '../public/holdSlot.js';
import { joinWaitlist } from '../public/joinWaitlist.js';
import { sendEmailCode } from '../public/sendEmailCode.js';
import { submitSealed } from '../public/submitSealed.js';
import { verifyEmailCode } from '../public/verifyEmailCode.js';
import { cancelBooking } from '../token/cancelBooking.js';
import { confirmPresence } from '../token/confirmPresence.js';
import { getBooking } from '../token/getBooking.js';
import { rebook } from '../token/rebook.js';
import { reportLate } from '../token/reportLate.js';
import { requestReschedule } from '../token/requestReschedule.js';
import { rescheduleBooking } from '../token/rescheduleBooking.js';
import type { AnyUseCase } from './UseCase.js';

export const USE_CASES: readonly AnyUseCase[] = [
  // public and token (the web booking app)
  getPublicPage, getSlots, holdSlot, getHold, sendEmailCode, verifyEmailCode, createBooking, findBookings, joinWaitlist,
  getBooking, confirmPresence, reportLate, cancelBooking, rescheduleBooking, requestReschedule, rebook,
  getFormContext, submitSealed, getPortal, forgetDevice,
  // owner (the iPhone app)
  ensureAccount, reserveRegistration, reserveRegistrations, syncPlan, isSlugAvailable, claimSlug, publishProfile,
  publishAvailability, updateInboxKey, respondBookingRequest, respondRescheduleRequest, cancelBookingByOwner,
  moveBookingByOwner, suggestBookingTime, mintManageLink, offerWaitlistSlot, removeWaitlistEntry, markNoShow,
  setOnlineBookingStopped, publishPortal,
  getMailboxItem, acknowledgeMailboxItem, registerDevice, unregisterDevice, deleteClientServerData, deleteAccount
];

export const USE_CASE_NAMES: readonly string[] = USE_CASES.map((useCase) => useCase.name);

export function findUseCase(name: string): AnyUseCase | undefined {
  return USE_CASES.find((useCase) => useCase.name === name);
}
