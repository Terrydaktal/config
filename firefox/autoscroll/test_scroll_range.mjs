import assert from "node:assert/strict";
import test from "node:test";
import { fixReverseScrollRange } from "./scroll-range.sys.mjs";

function buggyPrototype() {
  return {
    isScrollableElement(node) {
      return node.scrollable;
    },
    computeNodeScrollDirection(node) {
      if (!this.isScrollableElement(node)) {
        return null;
      }
      const vertical = node.scrollTopMax && !["hidden", "clip"].includes(node.overflow);
      if (node.horizontal) {
        return vertical ? "NSEW" : "EW";
      }
      return vertical ? "NS" : null;
    },
  };
}

function node(values = {}) {
  return {
    scrollable: true,
    scrollTopMin: -880,
    scrollTopMax: 0,
    overflow: "auto",
    horizontal: false,
    documentGlobal: {
      getComputedStyle(element) {
        return { getPropertyValue: () => element.overflow };
      },
    },
    ...values,
  };
}

test("reverse-flow vertical content is recognised without changing the node", () => {
  const prototype = buggyPrototype();
  const element = Object.freeze(node());
  const before = { ...element };
  assert.equal(prototype.computeNodeScrollDirection(element), null);
  assert.equal(fixReverseScrollRange(prototype), "applied");
  assert.equal(prototype.computeNodeScrollDirection(element), "NS");
  assert.deepEqual(element, before);
});

test("reverse-flow content with horizontal overflow scrolls both axes", () => {
  const prototype = buggyPrototype();
  assert.equal(fixReverseScrollRange(prototype), "applied");
  assert.equal(prototype.computeNodeScrollDirection(node({ horizontal: true })), "NSEW");
});

test("ordinary vertical and two-axis scrolling are unchanged", () => {
  const prototype = buggyPrototype();
  fixReverseScrollRange(prototype);
  assert.equal(prototype.computeNodeScrollDirection(node({ scrollTopMin: 0, scrollTopMax: 880 })), "NS");
  assert.equal(prototype.computeNodeScrollDirection(node({ scrollTopMin: 0, scrollTopMax: 880, horizontal: true })), "NSEW");
});

test("horizontal-only and non-overflowing elements are unchanged", () => {
  const prototype = buggyPrototype();
  fixReverseScrollRange(prototype);
  assert.equal(prototype.computeNodeScrollDirection(node({ scrollTopMin: 0, horizontal: true })), "EW");
  assert.equal(prototype.computeNodeScrollDirection(node({ scrollTopMin: 0 })), null);
});

test("hidden and clipped overflow remain blocked", () => {
  const prototype = buggyPrototype();
  fixReverseScrollRange(prototype);
  for (const overflow of ["hidden", "clip"]) {
    assert.equal(prototype.computeNodeScrollDirection(node({ overflow })), null);
    assert.equal(prototype.computeNodeScrollDirection(node({ overflow, horizontal: true })), "EW");
  }
});

test("non-scrollable elements and missing internal ranges are unchanged", () => {
  const prototype = buggyPrototype();
  fixReverseScrollRange(prototype);
  assert.equal(prototype.computeNodeScrollDirection(node({ scrollable: false })), null);
  for (const scrollTopMin of [undefined, NaN, -Infinity, 1]) {
    assert.equal(prototype.computeNodeScrollDirection(node({ scrollTopMin })), null);
  }
});

test("repeated installation does not wrap the method again", () => {
  const prototype = buggyPrototype();
  assert.equal(fixReverseScrollRange(prototype), "applied");
  const patched = prototype.computeNodeScrollDirection;
  assert.equal(fixReverseScrollRange(prototype), "already-applied");
  assert.equal(prototype.computeNodeScrollDirection, patched);
});

test("an upstream minimum/maximum implementation is left untouched", () => {
  const prototype = buggyPrototype();
  prototype.computeNodeScrollDirection = function(node) {
    return node.scrollTopMin !== node.scrollTopMax ? "NS" : null;
  };
  const original = prototype.computeNodeScrollDirection;
  assert.equal(fixReverseScrollRange(prototype), "not-needed");
  assert.equal(prototype.computeNodeScrollDirection, original);
});

test("unknown implementations and missing APIs are left untouched", () => {
  const prototype = buggyPrototype();
  prototype.computeNodeScrollDirection = () => "EW";
  const original = prototype.computeNodeScrollDirection;
  assert.equal(fixReverseScrollRange(prototype), "unsupported");
  assert.equal(prototype.computeNodeScrollDirection, original);
  for (const unsupported of [null, undefined, {}, { computeNodeScrollDirection() {} }]) {
    assert.equal(fixReverseScrollRange(unsupported), "unsupported");
  }
});
