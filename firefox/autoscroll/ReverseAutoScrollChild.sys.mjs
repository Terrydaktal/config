import { fixReverseScrollRange } from "./scroll-range.sys.mjs";

let checked = false;

export class ReverseAutoScrollChild extends JSWindowActorChild {
  handleEvent() {
    // System modules are per-process singletons, including the built-in actor.
    if (checked) {
      return;
    }
    checked = true;
    try {
      const { AutoScrollChild } = ChromeUtils.importESModule(
        "resource://gre/actors/AutoScrollChild.sys.mjs"
      );
      const result = fixReverseScrollRange(AutoScrollChild.prototype);
      if (result === "unsupported") {
        throw new Error("Unrecognised Firefox autoscroll implementation; left unchanged");
      }
    } catch (error) {
      Components.utils.reportError("Reverse autoscroll workaround: " + error);
    }
  }
}
