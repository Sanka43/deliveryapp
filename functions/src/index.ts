import {initializeApp} from "firebase-admin/app";

initializeApp();

export {
  validateCoupon,
  onOrderCreatedValidateCoupon,
} from "./coupons";
export {
  onOrderCreatedNotify,
  onOrderStatusUpdatedNotify,
  onVendorApprovalStatusUpdatedNotify,
} from "./orderNotifications";
export {onTripStatusUpdatedNotify} from "./tripNotifications";
export {
  onOrderCreatedVendorStats,
  onOrderUpdatedVendorStats,
} from "./vendorStats";
export {
  onStoreRatingCreated,
  onStoreRatingUpdated,
  onStoreRatingDeleted,
} from "./storeRatings";
export {
  onRiderRatingCreated,
  onRiderRatingUpdated,
  onRiderRatingDeleted,
} from "./riderRatings";
export {paymentWebhook} from "./paymentWebhook";
export {
  placeCashOnDeliveryOrder,
  createPayHereCheckoutForOrder,
  createPayHereCheckoutForExistingOrder,
  lookupVendorOrderCustomer,
  placeVendorManualOrder,
  completeDeliveryOrder,
  getVendorOrderRiderContact,
} from "./placeOrder";
export {
  adminMarkProductCashRemitted,
  adminMarkProductCashSettledToShop,
  riderMarkProductCashRemitted,
} from "./productCash";
export {
  onOrderDeliveredCreditRider,
  onTripCompletedCreditRider,
  requestRiderWithdrawal,
  adminSettleRiderWithdrawal,
} from "./riderEarnings";
export {
  riderRequestCashSettlement,
  adminConfirmCashSettlement,
  adminRejectCashSettlement,
} from "./riderCash";
export {sweepStaleRiderPresence} from "./riderPresence";
export {sweepRiderDocumentExpiry} from "./riderDocumentExpiry";
export {sweepStalePlacedOrders} from "./orderVendorAcceptReminders";
export {
  requestShopPasswordResetOtp,
  verifyShopPasswordResetOtp,
  confirmShopPasswordReset,
} from "./shopPasswordReset";
export {requestPhoneOtp, verifyPhoneOtp} from "./phoneOtp";
export {quoteRideFare, quoteRideFares} from "./rideFare";
export {
  confirmCashRide,
  createPayHereCheckout,
  createPayHereCheckoutForTrip,
  completeCashOrRideTrip,
  confirmCashRidePayment,
  sweepStaleSearchingTrips,
} from "./rideTrips";
export {payHereNotify, payHereCheckoutPage} from "./payHere";
export {getDrivingRoute, geocodePlace} from "./mapsProxy";
export {requestVendorAccountDeletion} from "./vendorAccountDeletion";
export {syncVendorOpenHours} from "./vendorOpenHours";
export {blockSyntheticRiderEmailSignup} from "./riderAuthBlocking";
export {
  createJobPost,
  sweepExpiredJobs,
  approveJobPost,
  rejectJobPost,
  onJobStatusUpdatedNotify,
  onJobApplicationCreatedNotify,
} from "./jobs";
