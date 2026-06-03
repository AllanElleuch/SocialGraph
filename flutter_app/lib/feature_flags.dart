/// Compile-time feature flags. Flip a value to toggle the feature; defaults are
/// the shipped behaviour.
library;

/// Shows the floating "Active view" legend panel over the Mutuals constellation
/// (the panel listing the active clustering, contact-node count, etc.).
/// Hidden by default — set to `true` to bring it back.
const bool kShowActiveViewLegend = false;
