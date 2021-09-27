window.goog = window.goog ?? {};
window.goog.soy = window.goog.soy ?? {};
window.goog.soy.data = window.goog.soy.data ?? {};
window.goog.soy.data.SanitizedHtmlAttribute = window.goog.soy.data.SanitizedHtmlAttribute ?? {};
window.goog.soy.data.SanitizedHtmlAttribute.isCompatibleWith = () => true;
window.goog.soy.data.SanitizedUri = window.goog.soy.data.SanitizedUri ?? {};
window.goog.soy.data.SanitizedUri.isCompatibleWith = () => true;

window.soy = window.soy ?? {};

window.soy.asserts = window.soy.asserts ?? {};
window.soy.asserts.assertType = function(_, _, param) {
  return param;
}

window.soy.assertParamType = function() {}

window.soy.$$areYouAnInternalCaller = function() {}

window.soy.$$equals = function(a, b) {
  return a === b;
}

window.soy.$$escapeHtml = function(value) {
  return value;
}

window.soy.$$escapeHtmlAttribute = function(value) {
  return value;
}

window.soy.$$escapeUri = function(value) {
  return value;
}

window.soy.$$filterCssValue = function(value) {
  return value;
}

window.soy.$$filterHtmlAttributes = function(value) {
  return value;
}

window.soy.$$filterNormalizeMediaUri = function(value) {
  return value;
}

window.soy.$$filterNormalizeUri = function(value) {
  return value;
}

window.soy.$$whitespaceHtmlAttributes = function(value) {
  return value;
}

window.soy = window.soy ?? {};
window.soy.VERY_UNSAFE = {
  $$ordainSanitizedAttributesForInternalBlocks: a => a,
  $$ordainSanitizedHtmlForInternalBlocks: a => a,
  ordainSanitizedHtml: a => a,
};
