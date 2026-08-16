// ==========================================
// UI, BEHAVIOR & ANNOYANCES
// ==========================================
user_pref("browser.startup.page", 3); // Restore previous session
user_pref("browser.tabs.groups.smart.enabled", false); // Disable smart tab groups
user_pref("browser.tabs.inTitlebar", 1); // Tabs in OS titlebar
user_pref("browser.tabs.tabMinWidth", 16); // Allow many tabs before overflow
user_pref("browser.toolbars.bookmarks.visibility", "never"); // Hide bookmarks toolbar
user_pref("browser.quitShortcut.disabled", true); // Disable Ctrl+Q
user_pref("browser.urlbar.placeholderName", "Google"); 
user_pref("browser.urlbar.placeholderName.private", "Google");
user_pref("layout.css.devPixelsPerPx", "1.0"); // 115% UI Scaling
user_pref("accessibility.typeaheadfind.flashBar", 0); // Disable Ctrl+F flash
user_pref("browser.aboutConfig.showWarning", false); // Disable about:config warning
user_pref("dom.forms.autocomplete.formautofill", true); // Enable form autofill

// ==========================================
// SCROLLING SPEED & PHYSICS
// ==========================================
user_pref("general.autoScroll", true); // Enable middle-click autoscroll
user_pref("mousewheel.default.delta_multiplier_y", 200); // Faster scroll distance
user_pref("general.smoothScroll", true);
user_pref("general.smoothScroll.mouseWheel.durationMaxMS", 100); // Snappy scroll animation
user_pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 600);
user_pref("general.smoothScroll.msdPhysics.regularSpringConstant", 600);
user_pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 10000); // Hard stop friction

// ==========================================
// PRIVACY, SECURITY & PERFORMANCE
// ==========================================
user_pref("browser.contentblocking.category", "custom"); // Custom tracking protection
user_pref("privacy.clearOnShutdown_v2.formdata", true); // Clear forms on shutdown
user_pref("network.http.speculative-parallel-limit", 0); // Disable link pre-loading
user_pref("dom.ipc.processCount.webIsolated", 8); // Higher per-site concurrency for heavy same-site workloads
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query"); // Cloudflare DoH
user_pref("privacy.trackingprotection.allow_list.baseline.enabled", false); // Strict tracker block
user_pref("privacy.trackingprotection.allow_list.convenience.enabled", false); // Strict tracker block

// ==========================================
// NVIDIA NVDEC
// ==========================================
//user_pref("media.hardware-video-decoding.force-enabled", true); // Enable VA-API decoding through nvidia-vaapi-driver
user_pref("media.hardware-video-decoding.enabled", true);

// ==========================================
// SPELLCHECK & LANGUAGE
// ==========================================
// AutoConfig unregisters Firefox's bundled en-US dictionary. This directory
// then leaves en-GB-large as the only dictionary available to page editors.
user_pref("spellchecker.dictionary_path", "/usr/local/share/firefox-dictionaries");
user_pref("spellchecker.dictionary", "en-GB-large"); // Firefox normalises dictionary filename underscores to hyphens
user_pref("layout.spellcheckDefault", 2); // 2 = Check all fields (including single-line inputs like search bars)
user_pref("intl.accept_languages", "en-GB, en"); // Prefer British English content when a site supports it
