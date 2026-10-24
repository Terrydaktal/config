// Repair native autoscroll for reverse-flow containers (Mozilla bug 1851749).
// Set config.reverseAutoscroll.enabled=false and restart to disable this.
(() => {
  try {
    const { classes: Cc, interfaces: Ci } = Components;
    const prefs = Cc["@mozilla.org/preferences-service;1"]
      .getService(Ci.nsIPrefService).getBranch("");
    if (!prefs.getBoolPref("config.reverseAutoscroll.enabled", true)) {
      return;
    }
    const moduleDirectory = Cc["@mozilla.org/file/directory_service;1"]
      .getService(Ci.nsIProperties).get("GreD", Ci.nsIFile);
    moduleDirectory.append("autoscroll");
    const moduleFile = moduleDirectory.clone();
    moduleFile.append("ReverseAutoScrollChild.sys.mjs");
    if (!moduleFile.isFile()) {
      throw new Error("Missing reverse autoscroll content module");
    }
    const ioService = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
    const resources = ioService.getProtocolHandler("resource")
      .QueryInterface(Ci.nsIResProtocolHandler);
    resources.setSubstitution("config-autoscroll", ioService.newFileURI(moduleDirectory));
    ChromeUtils.registerWindowActor("ReverseAutoScroll", {
      child: {
        esModuleURI: "resource://config-autoscroll/ReverseAutoScrollChild.sys.mjs",
        events: {
          DOMDocElementInserted: { capture: true, mozSystemGroup: true },
        },
      },
      allFrames: true,
      matches: ["https://*/*", "http://*/*", "file:///*"],
    });
  } catch (error) {
    Components.utils.reportError("Reverse autoscroll registration: " + error);
  }
})();
