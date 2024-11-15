function checkDOMPoint(p, exp) {
  assert_equals(p.x, exp.x, "Expected value for x is " + exp.x);
  assert_equals(p.y, exp.y, "Expected value for y is " + exp.y);
  assert_equals(p.z, exp.z, "Expected value for z is " + exp.z);
  assert_equals(p.w, exp.w, "Expected value for w is " + exp.w);
}

test(function() {
  checkDOMPoint(new DOMPoint(), {x:0, y:0, z:0, w:1});
},'testConstructor0');
test(function() {
  checkDOMPoint(new DOMPoint(1), {x:1, y:0, z:0, w:1});
},'testConstructor1');
test(function() {
  checkDOMPoint(new DOMPoint(1, 2), {x:1, y:2, z:0, w:1});
},'testConstructor2');
test(function() {
  checkDOMPoint(new DOMPoint(1, 2, 3), {x:1, y:2, z:3, w:1});
},'testConstructor3');
test(function() {
  checkDOMPoint(new DOMPoint(1, 2, 3, 4), {x:1, y:2, z:3, w:4});
},'testConstructor4');
test(function() {
  checkDOMPoint(new DOMPoint(1, 2, 3, 4, 5), {x:1, y:2, z:3, w:4});
},'testConstructor5');
// test(function() {
//   checkDOMPoint(new DOMPoint({}), {x:NaN, y:0, z:0, w:1});
// },'testConstructorDictionary0'); //TODO
// test(function() {
//   checkDOMPoint(new DOMPoint({x:1}), {x:NaN, y:0, z:0, w:1});
// },'testConstructorDictionary1'); //TODO
// test(function() {
//   checkDOMPoint(new DOMPoint({x:1, y:2}), {x:NaN, y:0, z:0, w:1});
// },'testConstructorDictionary2'); //TODO
test(function() {
  checkDOMPoint(new DOMPoint(1, undefined), {x:1, y:0, z:0, w:1});
},'testConstructor2undefined');
// test(function() {
//   checkDOMPoint(new DOMPoint("a", "b"), {x:NaN, y:NaN, z:0, w:1});
// },'testConstructorUndefined1'); //TODO
// test(function() {
//   checkDOMPoint(new DOMPoint({x:"a", y:"b"}), {x:NaN, y:0, z:0, w:1});
// },'testConstructorUndefined2'); //TODO
test(function() {
  checkDOMPoint(new DOMPointReadOnly(), {x:0, y:0, z:0, w:1});
},'DOMPointReadOnly constructor with no values');
test(function() {
  checkDOMPoint(new DOMPointReadOnly(1, 2, 3, 4), {x:1, y:2, z:3, w:4});
},'DOMPointReadOnly constructor with 4 values');
test(function() {
  var p = new DOMPoint(0, 0, 0, 1);
  p.x = undefined;
  p.y = undefined;
  p.z = undefined;
  p.w = undefined;
  checkDOMPoint(p, {x:NaN, y:NaN, z:NaN, w:NaN});
},'testAttributesUndefined'); //TODO
test(function() {
  var p = new DOMPoint(0, 0, 0, 1);
  p.x = NaN;
  p.y = Number.POSITIVE_INFINITY;
  p.z = Number.NEGATIVE_INFINITY;
  p.w = Infinity;
  checkDOMPoint(p, {x:NaN, y:Infinity, z:-Infinity, w:Infinity});
},'testAttributesNaNInfinity');  //TODO