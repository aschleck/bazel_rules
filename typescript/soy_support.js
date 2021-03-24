window.soy = window.soy || {};

window.soy.asserts = window.soy.asserts || {};
window.soy.asserts.assertType = function(_, _, param) {
  return param;
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

window.soy.$$filterNormalizeMediaUri = function(value) {
  return value;
}

window.soydata = window.soydata || {};
window.soydata.VERY_UNSAFE = {ordainSanitizedHtml: a => a};
