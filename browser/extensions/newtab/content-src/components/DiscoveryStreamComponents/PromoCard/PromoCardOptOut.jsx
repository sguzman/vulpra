/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// This module substitutes only for the opt-in Linux PromoCard experiment.
// AdBanner must remain bundled and render all normal sponsored-card content.
// Webpack substitutes this module before importing real PromoCard handlers.
export const PromoCard = () => null;
