/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Opt-in Vulpra bridge for builds that exclude Normandy's recipe runner.
 * The upstream Normandy startup path normally initializes Nimbus after
 * sessionstore-windows-restored. Keep that lifecycle without the runner.
 * Only packaged in the experimental Linux no-Normandy configuration.
 */
const UI_READY = "sessionstore-windows-restored";

export const NimbusBootstrap = {
  init() {
    Services.obs.addObserver(this, UI_READY);
  },

  observe(_subject, topic) {
    if (topic !== UI_READY) {
      return;
    }
    Services.obs.removeObserver(this, UI_READY);
    // The category caller must not block browser startup on Remote Settings.
    this.initializeNimbus();
  },

  async initializeNimbus() {
    try {
      const { ExperimentAPI } = ChromeUtils.importESModule(
        "resource://nimbus/ExperimentAPI.sys.mjs"
      );
      await ExperimentAPI.init();
    } catch (error) {
      console.error("Vulpra: Nimbus initialization failed", error);
    }
  },
};
