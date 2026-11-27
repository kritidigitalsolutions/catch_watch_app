/// A Restore flow is successful only after StoreKit returned a transaction and
/// the backend accepted its verification. Cached subscription/profile state by
/// itself is not evidence that a purchase was restored.
bool hasVerifiedRestoreTransaction(int verifiedTransactionCount) =>
    verifiedTransactionCount > 0;
