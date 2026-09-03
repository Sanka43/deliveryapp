/// Shared product availability rules for customer store / catalog UI.
///
/// Out of stock applies only when the vendor opted into stock tracking
/// (`manageStock`) and on-hand qty is zero. Catalogue visibility (`active`)
/// is filtered at query time — it is not an Out of stock signal.
bool productAvailabilityFromMap(Map<String, dynamic> map) {
  if (map['manageStock'] == true) {
    final dynamic stockQty = map['stockQty'];
    if (stockQty is num && stockQty.round() <= 0) {
      return false;
    }
  }
  return true;
}
