// Mozilla bug 1851749: reverse-flow content scrolls below zero, not above it.
const patchedMethods = new WeakSet();

export function fixReverseScrollRange(prototype) {
  const original = prototype?.computeNodeScrollDirection;
  if (typeof original !== "function" ||
      typeof prototype.isScrollableElement !== "function") {
    return "unsupported";
  }
  if (patchedMethods.has(original)) {
    return "already-applied";
  }

  const source = Function.prototype.toString.call(original);
  if (source.includes("scrollTopMin")) {
    return "not-needed";
  }
  if (!/\bnode\.scrollTopMax\s*&&/.test(source)) {
    return "unsupported";
  }

  const patched = function computeNodeScrollDirection(node) {
    const direction = original.call(this, node);
    if (direction !== null && direction !== "EW") {
      return direction;
    }
    if (!this.isScrollableElement(node) || node.scrollTopMax !== 0 ||
        !Number.isFinite(node.scrollTopMin) || node.scrollTopMin >= 0) {
      return direction;
    }

    const overflow = node.documentGlobal.getComputedStyle(node)
      .getPropertyValue("overflow-y");
    if (overflow === "hidden" || overflow === "clip") {
      return direction;
    }
    return direction === "EW" ? "NSEW" : "NS";
  };

  prototype.computeNodeScrollDirection = patched;
  patchedMethods.add(patched);
  return "applied";
}
