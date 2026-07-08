// ==========================================
// UI, BEHAVIOR & ANNOYANCES
// ==========================================
user_pref("browser.startup.page", 3); // Restore previous session
user_pref("browser.tabs.groups.smart.enabled", false); // Disable smart tab groups
user_pref("browser.tabs.inTitlebar", 1); // Tabs in OS titlebar
user_pref("browser.toolbars.bookmarks.visibility", "always"); // Always show bookmarks
user_pref("browser.urlbar.placeholderName", "Google"); 
user_pref("browser.urlbar.placeholderName.private", "Google");
user_pref("layout.css.devPixelsPerPx", "1.15"); // 115% UI Scaling
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
user_pref("dom.ipc.processCount.webIsolated", 8); // Limit web processes to 8
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query"); // Cloudflare DoH
user_pref("privacy.trackingprotection.allow_list.baseline.enabled", false); // Strict tracker block
user_pref("privacy.trackingprotection.allow_list.convenience.enabled", false); // Strict tracker block
