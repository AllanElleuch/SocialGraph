/// Compile-time feature flags. Flip a value to toggle the feature; defaults are
/// the shipped behaviour.
library;

/// Shows the floating "Active view" legend panel over the Mutuals constellation
/// (the panel listing the active clustering, contact-node count, etc.).
/// Hidden by default — set to `true` to bring it back.
const bool kShowActiveViewLegend = false;

/// When true, each constellation is rendered with a layout picked per run (so
/// the sky's shapes change between launches) instead of always the named figure.
/// A per-cluster override in the Constellations view always takes precedence.
const bool kRandomizeConstellationLayouts = true;
