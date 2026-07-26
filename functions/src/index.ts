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
export {
  onOrderCreatedVendorStats,
  onOrderUpdatedVendorStats,
} from "./vendorStats";
export {
  onStoreRatingCreated,
  onStoreRatingUpdated,
  onStoreRatingDeleted,
} from "./storeRatings";
export {paymentWebhook} from "./paymentWebhook";
export {devRiderOtpSignIn} from "./devRiderAuth";
export {
  requestShopPasswordResetOtp,
  verifyShopPasswordResetOtp,
  confirmShopPasswordReset,
} from "./shopPasswordReset";
