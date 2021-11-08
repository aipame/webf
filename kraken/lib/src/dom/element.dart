/*
 * Copyright (C) 2019-present Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:kraken/bridge.dart';
import 'package:kraken/css.dart';
import 'package:kraken/dom.dart';
import 'package:kraken/rendering.dart';
import 'package:kraken/src/dom/sliver_manager.dart';
import 'package:meta/meta.dart';

import 'element_native_methods.dart';

final RegExp _splitRegExp = RegExp(r'\s+');
const String _ONE_SPACE = ' ';
const String _STYLE_PROPERTY = 'style';
const String _CLASS_NAME = 'class';

/// Defined by W3C Standard,
/// Most element's default width is 300 in pixel,
/// height is 150 in pixel.
const String ELEMENT_DEFAULT_WIDTH = '300px';
const String ELEMENT_DEFAULT_HEIGHT = '150px';

typedef TestElement = bool Function(Element element);

enum StickyPositionType {
  relative,
  fixed,
}

enum BoxSizeType {
  // Element which have intrinsic before layout. Such as <img /> and <video />
  intrinsic,

  // Element which have width or min-width properties defined.
  specified,

  // Element which neither have intrinsic or predefined size.
  automatic,
}

mixin ElementBase on Node {
  RenderLayoutBox? _renderLayoutBox;
  RenderIntrinsic? _renderIntrinsic;

  RenderBoxModel? get renderBoxModel => _renderLayoutBox ?? _renderIntrinsic;
  set renderBoxModel(RenderBoxModel? value) {
    if (value == null) {
      _renderIntrinsic = null;
      _renderLayoutBox = null;
    } else if (value is RenderIntrinsic) {
      _renderIntrinsic = value;
    } else if (value is RenderLayoutBox) {
      _renderLayoutBox = value;
    } else {
      if (!kReleaseMode) throw FlutterError('Unknown RenderBoxModel value.');
    }
  }

  late RenderStyle renderStyle;
}

typedef BeforeRendererAttach = RenderObject Function();
typedef GetTargetId = int Function();
typedef GetRootElementFontSize = double Function();
typedef GetChildNodes = List<Node> Function();
/// Get the viewport size of current element.
typedef GetViewportSize = Size Function();
/// Get the render box model of current element.
typedef GetRenderBoxModel = RenderBoxModel? Function();

class Element extends Node
    with
        ElementBase,
        ElementNativeMethods,
        ElementEventMixin,
        ElementOverflowMixin {

  final Map<String, dynamic> properties = <String, dynamic>{};

  /// Should create repaintBoundary for this element to repaint separately from parent.
  bool repaintSelf;

  // Default to unknown, assign by [createElement], used by inspector.
  String tagName = UNKNOWN;

  /// Is element an intrinsic box.
  final bool _isIntrinsicBox;

  /// The style of the element, not inline style.
  late CSSStyleDeclaration style;

  /// The default user-agent style.
  final Map<String, dynamic> _defaultStyle;

  /// The inline style is a map of style property name to style property value.
  final Map<String, dynamic> inlineStyle = {};

  /// The Element.classList is a read-only property that returns a collection of the class attributes of the element.
  final List<String> _classList = [];
  List<String> get classList {
    return _classList;
  }

  set className(String className) {
    _classList.clear();
    List<String> classList = className.split(_splitRegExp);
    if (classList.isNotEmpty) {
      _classList.addAll(classList);
    }
    recalculateStyle();
  }
  String get className => _classList.join(_ONE_SPACE);

  /// Whether should create repaintBoundary for this element when style changed
  bool get shouldConvertToRepaintBoundary {
    // Following cases should always convert to repaint boundary for performance consideration
    // Intrinsic element such as Canvas
    bool isSetRepaintSelf = repaintSelf;
    // Scrolling box
    bool isScrollingBox = scrollingContentLayoutBox != null;
    // Transform element
    bool hasTransform = renderBoxModel?.renderStyle.transformMatrix != null;
    // Fixed element
    bool isPositionedFixed = renderBoxModel?.renderStyle.position == CSSPositionType.fixed;

    return isScrollingBox || isSetRepaintSelf || hasTransform || isPositionedFixed;
  }

  Element(int targetId, Pointer<NativeEventTarget> nativeEventTarget, ElementManager elementManager,
      { Map<String, dynamic> defaultStyle = const {},
        // Whether element allows children.
        bool isIntrinsicBox = false,
        this.repaintSelf = false})
      : _defaultStyle = defaultStyle,
        _isIntrinsicBox = isIntrinsicBox,
        super(NodeType.ELEMENT_NODE, targetId, nativeEventTarget, elementManager) {

    // Init style and add change listener.
    style = CSSStyleDeclaration.computedStyle(this, _defaultStyle, _onStyleChanged);

    // Init render style.
    renderStyle = RenderStyle(target: this);
  }

  @override
  String get nodeName => tagName;

  @override
  RenderBox? get renderer => renderBoxModel;

  @override
  RenderBox createRenderer() {
    if (renderBoxModel != null) {
      return renderBoxModel!;
    }
    createRenderBoxModel();
    return renderBoxModel!;
  }

  void createRenderBoxModel({ bool? shouldRepaintSelf }) {
    // Content children layout, BoxModel content.
    if (_isIntrinsicBox) {
      _renderIntrinsic = _createRenderIntrinsic(repaintSelf: shouldRepaintSelf ?? repaintSelf, prevRenderIntrinsic: _renderIntrinsic);
    } else {
      _renderLayoutBox = _createRenderLayout(repaintSelf: shouldRepaintSelf ?? repaintSelf, prevRenderLayoutBox: _renderLayoutBox);
    }
    // Ensure that the event responder is bound.
    _ensureEventResponderBound();
  }

  @override
  void willAttachRenderer() {
    // Init render box model.
    createRenderer();
  }

  @override
  void didAttachRenderer() {
    // Ensure that the child is attached.
    ensureChildAttached();
  }

  @override
  void willDetachRenderer() {
    // Cancel running transition.
    renderStyle.cancelRunningTransiton();
    // Remove all intersection change listeners.
    renderBoxModel!.clearIntersectionChangeListeners();

    // Remove fixed children from root when dispose.
    _removeFixedChild(renderBoxModel!);

    // Remove renderbox.
    _removeRenderBoxModel(parent!.renderer, renderBoxModel);
  }

  @override
  void didDetachRenderer() {
    style.reset();
  }

  bool _shouldConsumeScrollTicker = false;
  void _consumeScrollTicker(_) {
    if (_shouldConsumeScrollTicker && eventHandlers.containsKey(EVENT_SCROLL)) {
      _dispatchScrollEvent();
      _shouldConsumeScrollTicker = false;
    }
  }

  void _handleScroll(double scrollOffset, AxisDirection axisDirection) {
    applyStickyChildrenOffset();
    paintFixedChildren(scrollOffset, axisDirection);

    if (!_shouldConsumeScrollTicker) {
      // Make sure scroll listener trigger most to 1 time each frame.
      SchedulerBinding.instance!.addPostFrameCallback(_consumeScrollTicker);
      SchedulerBinding.instance!.scheduleFrame();
    }
    _shouldConsumeScrollTicker = true;
  }

  /// https://drafts.csswg.org/cssom-view/#scrolling-events
  void _dispatchScrollEvent() {
    dispatchEvent(Event(EVENT_SCROLL));
  }

  /// Normally element in scroll box will not repaint on scroll because of repaint boundary optimization
  /// So it needs to manually mark element needs paint and add scroll offset in paint stage
  void paintFixedChildren(double scrollOffset, AxisDirection axisDirection) {
    RenderLayoutBox? _scrollingContentLayoutBox = scrollingContentLayoutBox;
    // Only root element has fixed children
    if (targetId == HTML_ID && _scrollingContentLayoutBox != null) {
      for (RenderBoxModel child in _scrollingContentLayoutBox.fixedChildren) {
        // Save scrolling offset for paint
        if (axisDirection == AxisDirection.down) {
          child.scrollingOffsetY = scrollOffset;
        } else if (axisDirection == AxisDirection.right) {
          child.scrollingOffsetX = scrollOffset;
        }
      }
    }
  }

  // Calculate sticky status according to scroll offset and scroll direction
  void applyStickyChildrenOffset() {
    RenderLayoutBox? scrollContainer = (renderBoxModel as RenderLayoutBox?)!;
    for (RenderBoxModel stickyChild in scrollContainer.stickyChildren) {
      CSSPositionedLayout.applyStickyChildOffset(scrollContainer, stickyChild);
    }
  }

  /// Convert renderBoxModel to non repaint boundary
  void convertToNonRepaintBoundary() {
    RenderBoxModel? _renderBoxModel = renderBoxModel;
    if (_renderBoxModel != null && _renderBoxModel.isRepaintBoundary) {
      _toggleRepaintSelf(repaintSelf: false);
    }
  }

  /// Convert renderBoxModel to repaint boundary
  void convertToRepaintBoundary() {
    RenderBoxModel? _renderBoxModel = renderBoxModel;
    if (_renderBoxModel != null && !_renderBoxModel.isRepaintBoundary) {
      _toggleRepaintSelf(repaintSelf: true);
    }
  }

  /// Toggle renderBoxModel between repaint boundary and non repaint boundary.
  void _toggleRepaintSelf({ required bool repaintSelf }) {
    RenderBoxModel _renderBoxModel = renderBoxModel!;
    RenderBox? parentRenderObject = _renderBoxModel.parent as RenderBox?;
    RenderBox? previousSibling;
    List<RenderBox>? sortedChildren;
    // Remove old renderObject
    if (parentRenderObject is ContainerRenderObjectMixin) {
      ContainerParentDataMixin<RenderBox>? _parentData = _renderBoxModel.parentData as ContainerParentDataMixin<RenderBox>?;
      if (_parentData != null) {
        previousSibling = _parentData.previousSibling;
        // Get the renderBox before the RenderPositionHolder to find the renderBox to insert after
        // cause renderPositionHolder of sticky element lays before the renderBox.
        if (previousSibling is RenderPositionHolder) {
          ContainerParentDataMixin<RenderBox>? _parentData = previousSibling.parentData as ContainerParentDataMixin<RenderBox>?;
          if (_parentData != null) {
            previousSibling = _parentData.previousSibling;
          }
        }
        // Cache sortedChildren cause it will be cleared when renderLayoutBox is detached from tree.
        if (_renderBoxModel is RenderLayoutBox) {
          sortedChildren = _renderBoxModel.sortedChildren;
        }
        (parentRenderObject as ContainerRenderObjectMixin).remove(_renderBoxModel);
      }
    }

    createRenderBoxModel(shouldRepaintSelf: repaintSelf);

    // Assign sortedChildren to newly created RenderLayoutBox.
    if (renderBoxModel is RenderLayoutBox && sortedChildren != null) {
      (renderBoxModel as RenderLayoutBox).sortedChildren = sortedChildren;
    }

    // Attach new renderBox.
    _attachRenderBoxModel(parentRenderObject, renderBoxModel);
  }

  void _updateRenderBoxModelWithPosition() {
    // Move element according to position when it's already attached to render tree.
    if (!isRendererAttached) {
      return;
    }

    RenderBoxModel _renderBoxModel = renderBoxModel!;
    Element _parentElement = parentElement!;
    CSSPositionType currentPosition = renderStyle.position;

    // Remove fixed children before convert to non repaint boundary renderObject
    if (currentPosition != CSSPositionType.fixed) {
      _removeFixedChild(_renderBoxModel);
    }

    RenderBox? prev = (_renderBoxModel.parentData as ContainerParentDataMixin<RenderBox>).previousSibling;
    // It needs to find the previous sibling of the previous sibling if the placeholder of
    // positioned element exists and follows renderObject at the same time, eg.
    // <div style="position: relative"><div style="position: absolute" /></div>
    if (prev == _renderBoxModel) {
      prev = (_renderBoxModel.parentData as ContainerParentDataMixin<RenderBox>).previousSibling;
    }

    // Remove renderBoxModel from original parent and append to its containing block
    _removeRenderBoxModel(_renderBoxModel.parent as RenderBox?, _renderBoxModel);
    _parentElement.addChildRenderObject(this, after: prev);

    if (shouldConvertToRepaintBoundary) {
      convertToRepaintBoundary();
    } else {
      convertToNonRepaintBoundary();
    }

    // Add fixed children after convert to repaint boundary renderObject
    if (currentPosition == CSSPositionType.fixed) {
      _addFixedChild(renderBoxModel!);
    }
  }

  Element? getElementById(Element parentElement, int targetId) {
    Element? result;
    List childNodes = parentElement.childNodes;

    for (int i = 0; i < childNodes.length; i++) {
      Element element = childNodes[i];
      if (element.targetId == targetId) {
        result = element;
        break;
      }
    }
    return result;
  }

  void addChild(RenderBox child) {
    if (_renderLayoutBox != null) {
      if (scrollingContentLayoutBox != null) {
        scrollingContentLayoutBox!.add(child);
      } else {
        _renderLayoutBox!.add(child);
      }
    } else if (_renderIntrinsic != null) {
      _renderIntrinsic!.child = child;
    }
  }

  @override
  void dispose() {
    super.dispose();

    if (isRendererAttached) {
      disposeRenderObject();
    }

    RenderBoxModel? _renderBoxModel = renderBoxModel;
    Element? _parentElement = parentElement;

    // Call dispose method of renderBoxModel when GC auto dispose element
    if (_renderBoxModel != null) {
      _renderBoxModel.dispose();
    }

    if (_parentElement != null) {
      _parentElement.removeChild(this);
    }

    renderStyle.detach();
    style.dispose();
    properties.clear();
  }

  // Used for force update layout.
  void flushLayout() {
    if (isRendererAttached) {
      renderer!.owner!.flushLayout();
    }
  }

  void addChildRenderObject(Element child, {RenderBox? after}) {
    CSSPositionType positionType = child.renderBoxModel!.renderStyle.position;
    RenderLayoutBox? _scrollingContentLayoutBox = scrollingContentLayoutBox;
    switch (positionType) {
      case CSSPositionType.absolute:
      case CSSPositionType.fixed:
        _addPositionedChild(child, positionType);
        break;
      case CSSPositionType.sticky:
      case CSSPositionType.relative:
      case CSSPositionType.static:
        RenderLayoutBox? parentRenderLayoutBox = _scrollingContentLayoutBox ?? _renderLayoutBox;

        if (parentRenderLayoutBox != null) {
          parentRenderLayoutBox.insert(child.renderBoxModel!, after: after);

          if (positionType == CSSPositionType.sticky) {
            _addPositionHolder(parentRenderLayoutBox, child, positionType);
          }
        }
        break;
    }
  }

  // Attach renderObject of current node to parent
  @override
  void attachTo(Node parent, {RenderBox? after}) {
    _applyStyle(style);

    if (renderStyle.display != CSSDisplay.none) {
      willAttachRenderer();

      if (parent is Element) {
        parent.addChildRenderObject(this, after: after);
      } else if (parent is Document) {
        parent.appendChild(this);
      }
      // Flush pending style before child attached.
      style.flushPendingProperties();
      // Delay position set on node attach cause position depends on renderStyle of parent.
      _updateRenderBoxModelWithPosition();

      didAttachRenderer();
    }
  }

  /// Release any resources held by [renderBoxModel].
  @override
  void disposeRenderObject() {
    if (renderBoxModel == null) return;

    willDetachRenderer();

    for (Node child in childNodes) {
      child.disposeRenderObject();
    }

    didDetachRenderer();

    // Call dispose method of renderBoxModel when it is detached from tree.
    renderBoxModel!.dispose();
    renderBoxModel = null;
  }

  @override
  void ensureChildAttached() {
    if (isRendererAttached) {
      for (Node child in childNodes) {
        if (_renderLayoutBox != null && !child.isRendererAttached) {
          RenderBox? after;
          if (scrollingContentLayoutBox != null) {
            after = scrollingContentLayoutBox!.lastChild;
          } else {
            after = _renderLayoutBox!.lastChild;
          }

          child.attachTo(this, after: after);
          child.ensureChildAttached();
        }
      }
    }
  }

  @override
  @mustCallSuper
  Node appendChild(Node child) {
    super.appendChild(child);
    // Update renderStyle tree.
    if (child is Element) {
      child.renderStyle.parent = renderStyle;
    }
    if (isRendererAttached) {
      // Only append child renderer when which is not attached.
      if (!child.isRendererAttached) {
        if (scrollingContentLayoutBox != null) {
          child.attachTo(this, after: scrollingContentLayoutBox!.lastChild);
        } else if (!_isIntrinsicBox) {
          child.attachTo(this, after: _renderLayoutBox!.lastChild);
        }
      }
    }

    return child;
  }

  @override
  @mustCallSuper
  Node removeChild(Node child) {
    // Not remove node type which is not present in RenderObject tree such as Comment
    // Only append node types which is visible in RenderObject tree
    // Only remove childNode when it has parent
    if (child.isRendererAttached) {
      child.disposeRenderObject();
    }
    // Update renderStyle tree.
    if (child is Element) {
      child.renderStyle.detach();
    }

    super.removeChild(child);
    return child;
  }

  @override
  @mustCallSuper
  Node insertBefore(Node child, Node referenceNode) {
    // Node.insertBefore will change element tree structure,
    // so get the referenceIndex before calling it.
    int referenceIndex = childNodes.indexOf(referenceNode);
    Node node = super.insertBefore(child, referenceNode);
    // Update renderStyle tree.
    if (child is Element) {
      child.renderStyle.parent = renderStyle;
    }

    if (isRendererAttached) {
      // Only append child renderer when which is not attached.
      if (!child.isRendererAttached) {
        RenderBox? afterRenderObject;
        // `referenceNode` should not be null, or `referenceIndex` can only be -1.
        if (referenceIndex != -1 && referenceNode.isRendererAttached) {
          afterRenderObject = (referenceNode.renderer!.parentData as ContainerParentDataMixin<RenderBox>).previousSibling;
        }
        child.attachTo(this, after: afterRenderObject);
      }
    }

    return node;
  }

  @override
  @mustCallSuper
  Node? replaceChild(Node newNode, Node oldNode) {
    // Update renderStyle tree.
    if (newNode is Element) {
      newNode.renderStyle.parent = renderStyle;
    }
    if (oldNode is Element) {
      oldNode.renderStyle.parent = null;
    }
    return super.replaceChild(newNode, oldNode);
  }

  void _addPositionedChild(Element child, CSSPositionType position) {
    Element? containingBlockElement;
    switch (position) {
      case CSSPositionType.absolute:
        containingBlockElement = _findContainingBlock(child);
        break;
      case CSSPositionType.fixed:
        containingBlockElement = elementManager.viewportElement;
        break;
      default:
        return;
    }

    RenderLayoutBox parentRenderLayoutBox = containingBlockElement!.scrollingContentLayoutBox != null ?
      containingBlockElement.scrollingContentLayoutBox! : containingBlockElement._renderLayoutBox!;
    RenderBoxModel childRenderBoxModel = child.renderBoxModel!;
    _setPositionedChildParentData(parentRenderLayoutBox, child);
    parentRenderLayoutBox.add(childRenderBoxModel);

    _addPositionHolder(parentRenderLayoutBox, child, position);
  }

  void _addPositionHolder(RenderLayoutBox parentRenderLayoutBox, Element child, CSSPositionType position) {
    Size preferredSize = Size.zero;
    RenderBoxModel childRenderBoxModel = child.renderBoxModel!;
    // Position holder size will be updated on layout.
    preferredSize = Size(0, 0);
    RenderPositionHolder childPositionHolder = RenderPositionHolder(preferredSize: preferredSize);
    childRenderBoxModel.renderPositionHolder = childPositionHolder;
    childPositionHolder.realDisplayedBox = childRenderBoxModel;

    if (position == CSSPositionType.sticky) {
      // Placeholder of sticky renderBox need to inherit offset from original renderBox,
      // so it needs to layout before original renderBox
      RenderBox? preSibling = parentRenderLayoutBox.childBefore(childRenderBoxModel);
      parentRenderLayoutBox.insert(childPositionHolder, after: preSibling);
    } else {
      // Placeholder of flexbox needs to inherit size from its real display box,
      // so it needs to layout after real box layout
      child.parentElement!.addChild(childPositionHolder);
    }
  }

  /// Cache fixed renderObject to root element
  void _addFixedChild(RenderBoxModel childRenderBoxModel) {
    Element rootEl = elementManager.viewportElement;
    RenderLayoutBox rootRenderLayoutBox = rootEl.scrollingContentLayoutBox!;
    List<RenderBoxModel> fixedChildren = rootRenderLayoutBox.fixedChildren;
    if (!fixedChildren.contains(childRenderBoxModel)) {
      fixedChildren.add(childRenderBoxModel);
    }
  }

  /// Remove non fixed renderObject to root element
  void _removeFixedChild(RenderBoxModel childRenderBoxModel) {
    Element rootEl = elementManager.viewportElement;
    RenderLayoutBox? rootRenderLayoutBox = rootEl.scrollingContentLayoutBox!;
    List<RenderBoxModel> fixedChildren = rootRenderLayoutBox.fixedChildren;
    if (fixedChildren.contains(childRenderBoxModel)) {
      fixedChildren.remove(childRenderBoxModel);
    }
  }

  // FIXME: only compatible with kraken plugins
  @deprecated
  void setStyle(String property, dynamic value) {
    setRenderStyle(property, value);
  }

  void _updateRenderBoxModelWithDisplay() {
    CSSDisplay presentDisplay = renderStyle.display;

    if (parent == null || !parent!.isConnected) return;

    // Destroy renderer of element when display is changed to none.
    if (presentDisplay == CSSDisplay.none) {
      disposeRenderObject();
      return;
    }

    // When renderer and style listener is not created when original display is none,
    // thus it needs to create renderer when style changed.
    if (renderBoxModel == null) {
      // Update renderBoxModel and attach it to parent.
      createRenderBoxModel();
      _attachRenderBoxModel(parent!.renderer, renderBoxModel);
      // FIXME: avoid ensure something in display updating.
      ensureChildAttached();
      return;
    }

    // Inline block/flex to block/flex do not need create new renderBoxModel.
    if ((renderBoxModel is RenderFlowLayout &&
        (presentDisplay == CSSDisplay.inline || presentDisplay == CSSDisplay.block || presentDisplay == CSSDisplay.inlineBlock)) ||
        (renderBoxModel is RenderFlexLayout &&
            (presentDisplay == CSSDisplay.flex || presentDisplay == CSSDisplay.inlineFlex))) {
      return;
    }

    if (renderBoxModel is RenderLayoutBox) {
      // Update layout box type from block to flex.
      _removeRenderBoxModel(parent!.renderer, renderBoxModel);
      createRenderBoxModel();
      _attachRenderBoxModel(parent!.renderer, renderBoxModel);
    }
  }

  void _attachRenderBoxModel(RenderBox? parentRenderBox, RenderBoxModel? currentRenderBox) {
    if (parentRenderBox is RenderViewportBox) {
      parentRenderBox.child = currentRenderBox;
    } else if (parentRenderBox is RenderLayoutBox) {
      if (currentRenderBox != null) {
        Node? previousSibling = this.previousSibling;
        RenderObject? previous = previousSibling?.renderer;
        parentRenderBox.insert(currentRenderBox, after: previous as RenderBox?);
      }
    }
  }

  void _removeRenderBoxModel(RenderBox? parentRenderBox, RenderBoxModel? prevRendeBox) {
     if (parentRenderBox is RenderViewportBox) {
      parentRenderBox.child = null;
    } else if (parentRenderBox is RenderLayoutBox) {
      if (prevRendeBox != null) {
        parentRenderBox.remove(prevRendeBox);
      }
    }

    if (prevRendeBox != null) {
      // Remove placeholder of positioned element.
      RenderPositionHolder? renderPositionHolder = prevRendeBox.renderPositionHolder;
      if (renderPositionHolder != null) {
        RenderLayoutBox? parent = renderPositionHolder.parent as RenderLayoutBox?;
        if (parent != null) {
          parent.remove(renderPositionHolder);
        }
      }
    }
  }

  void setRenderStyleProperty(String name, dynamic value) {
    switch (name) {
      case DISPLAY:
        renderStyle.display = value;
         _updateRenderBoxModelWithDisplay();
        break;
      case Z_INDEX:
        renderStyle.zIndex = value;
        _updateRenderBoxModelWithZIndex();
        break;
      case OVERFLOW_X:
        CSSOverflowType oldEffectiveOverflowY = renderStyle.effectiveOverflowY;
        renderStyle.overflowX = value;
        updateRenderBoxModelWithOverflowX(_handleScroll);

        // Change overflowX may affect effectiveOverflowY.
        // https://drafts.csswg.org/css-overflow/#overflow-properties
        CSSOverflowType effectiveOverflowY = renderStyle.effectiveOverflowY;
        if (effectiveOverflowY != oldEffectiveOverflowY) {
          updateRenderBoxModelWithOverflowY(_handleScroll);
        }
        break;
      case OVERFLOW_Y:
        CSSOverflowType oldEffectiveOverflowX = renderStyle.effectiveOverflowX;
        renderStyle.overflowY = value;
        updateRenderBoxModelWithOverflowY(_handleScroll);

        // Change overflowY may affect the effectiveOverflowX.
        // https://drafts.csswg.org/css-overflow/#overflow-properties
        CSSOverflowType effectiveOverflowX = renderStyle.effectiveOverflowX;
        if (effectiveOverflowX != oldEffectiveOverflowX) {
          updateRenderBoxModelWithOverflowX(_handleScroll);
        }
        break;
      case OPACITY:
        renderStyle.opacity = value;
        break;
      case VISIBILITY:
        renderStyle.visibility = value;
        break;
      case CONTENT_VISIBILITY:
        renderStyle.contentVisibility = value;
        break;
      case POSITION:
        renderStyle.position = value;
        _updateRenderBoxModelWithPosition();
        break;
      case TOP:
        renderStyle.top = value;
        break;
      case LEFT:
        renderStyle.left = value;
        break;
      case BOTTOM:
        renderStyle.bottom = value;
        break;
      case RIGHT:
        renderStyle.right = value;
        break;
      // Size
      case WIDTH:
        renderStyle.width = value;
        break;
      case MIN_WIDTH:
        renderStyle.minWidth = value;
        break;
      case MAX_WIDTH:
        renderStyle.maxWidth = value;
        break;
      case HEIGHT:
        renderStyle.height = value;
        break;
      case MIN_HEIGHT:
        renderStyle.minHeight = value;
        break;
      case MAX_HEIGHT:
        renderStyle.maxHeight = value;
        break;
      // Flex
      case FLEX_DIRECTION:
        renderStyle.flexDirection = value;
        break;
      case FLEX_WRAP:
        renderStyle.flexWrap = value;
        break;
      case ALIGN_CONTENT:
        renderStyle.alignContent = value;
        break;
      case ALIGN_ITEMS:
        renderStyle.alignItems = value;
        break;
      case JUSTIFY_CONTENT:
        renderStyle.justifyContent = value;
        break;
      case ALIGN_SELF:
        renderStyle.alignSelf = value;
        break;
      case FLEX_GROW:
        renderStyle.flexGrow = value;
        break;
      case FLEX_SHRINK:
        renderStyle.flexShrink = value;
        break;
      case FLEX_BASIS:
        renderStyle.flexBasis = value;
        break;
      // Background
      case BACKGROUND_COLOR:
        renderStyle.backgroundColor = value;
        break;
      case BACKGROUND_ATTACHMENT:
        renderStyle.backgroundAttachment = value;
        break;
      case BACKGROUND_IMAGE:
        renderStyle.backgroundImage = value;
        break;
      case BACKGROUND_REPEAT:
        renderStyle.backgroundRepeat = value;
        break;
      case BACKGROUND_POSITION_X:
        renderStyle.backgroundPositionX = value;
        break;
      case BACKGROUND_POSITION_Y:
        renderStyle.backgroundPositionY = value;
        break;
      case BACKGROUND_SIZE:
        renderStyle.backgroundSize = value;
        break;
      case BACKGROUND_CLIP:
        renderStyle.backgroundClip = value;
        break;
      case BACKGROUND_ORIGIN:
        renderStyle.backgroundOrigin = value;
        break;
      // Padding
      case PADDING_TOP:
        renderStyle.paddingTop = value;
        break;
      case PADDING_RIGHT:
        renderStyle.paddingRight = value;
        break;
      case PADDING_BOTTOM:
        renderStyle.paddingBottom = value;
        break;
      case PADDING_LEFT:
        renderStyle.paddingLeft = value;
        break;
      // Border
      case BORDER_LEFT_WIDTH:
        renderStyle.borderLeftWidth = value;
        break;
      case BORDER_TOP_WIDTH:
        renderStyle.borderTopWidth = value;
        break;
      case BORDER_RIGHT_WIDTH:
        renderStyle.borderRightWidth = value;
        break;
      case BORDER_BOTTOM_WIDTH:
        renderStyle.borderBottomWidth = value;
        break;
      case BORDER_LEFT_STYLE:
        renderStyle.borderLeftStyle = value;
        break;
      case BORDER_TOP_STYLE:
        renderStyle.borderTopStyle = value;
        break;
      case BORDER_RIGHT_STYLE:
        renderStyle.borderRightStyle = value;
        break;
      case BORDER_BOTTOM_STYLE:
        renderStyle.borderBottomStyle = value;
        break;
      case BORDER_LEFT_COLOR:
        renderStyle.borderLeftColor = value;
        break;
      case BORDER_TOP_COLOR:
        renderStyle.borderTopColor = value;
        break;
      case BORDER_RIGHT_COLOR:
        renderStyle.borderRightColor = value;
        break;
      case BORDER_BOTTOM_COLOR:
        renderStyle.borderBottomColor = value;
        break;
      case BOX_SHADOW:
        renderStyle.boxShadow = value;
        break;
      case BORDER_TOP_LEFT_RADIUS:
        renderStyle.borderTopLeftRadius = value;
        break;
      case BORDER_TOP_RIGHT_RADIUS:
        renderStyle.borderTopRightRadius = value;
        break;
      case BORDER_BOTTOM_LEFT_RADIUS:
        renderStyle.borderBottomLeftRadius = value;
        break;
      case BORDER_BOTTOM_RIGHT_RADIUS:
        renderStyle.borderBottomRightRadius = value;
        break;
      // Margin
      case MARGIN_LEFT:
        renderStyle.marginLeft = value;
        break;
      case MARGIN_TOP:
        renderStyle.marginTop = value;
        break;
      case MARGIN_RIGHT:
        renderStyle.marginRight = value;
        break;
      case MARGIN_BOTTOM:
        renderStyle.marginBottom = value;
        break;
      // Text
      case COLOR:
        renderStyle.color = value;
        _updateColorRelativePropertyWithColor(this);
        break;
      case TEXT_DECORATION_LINE:
        renderStyle.textDecorationLine = value;
        break;
      case TEXT_DECORATION_STYLE:
        renderStyle.textDecorationStyle = value;
        break;
      case TEXT_DECORATION_COLOR:
        renderStyle.textDecorationColor = value;
        break;
      case FONT_WEIGHT:
        renderStyle.fontWeight = value;
        break;
      case FONT_STYLE:
        renderStyle.fontStyle = value;
        break;
      case FONT_FAMILY:
        renderStyle.fontFamily = value;
        break;
      case FONT_SIZE:
        renderStyle.fontSize = value;
        _updateFontRelativeLengthWithFontSize();
        break;
      case LINE_HEIGHT:
        renderStyle.lineHeight = value;
        break;
      case LETTER_SPACING:
        renderStyle.letterSpacing = value;
        break;
      case WORD_SPACING:
        renderStyle.wordSpacing = value;
        break;
      case TEXT_SHADOW:
        renderStyle.textShadow = value;
        break;
      case WHITE_SPACE:
        renderStyle.whiteSpace = value;
        break;
      case TEXT_OVERFLOW:
        // Overflow will affect text-overflow ellipsis taking effect
        renderStyle.textOverflow = value;
        break;
      case LINE_CLAMP:
        renderStyle.lineClamp = value;
        break;
      case VERTICAL_ALIGN:
        renderStyle.verticalAlign = value;
        break;
      case TEXT_ALIGN:
        renderStyle.textAlign = value;
        break;
      // Transform
      case TRANSFORM:
        renderStyle.transform = value;
        break;
      case TRANSFORM_ORIGIN:
        renderStyle.transformOrigin = value;
        break;
      // Transition
      case TRANSITION_DELAY:
        renderStyle.transitionDelay = value;
        break;
      case TRANSITION_DURATION:
        renderStyle.transitionDuration = value;
        break;
      case TRANSITION_TIMING_FUNCTION:
        renderStyle.transitionTimingFunction = value;
        break;
      case TRANSITION_PROPERTY:
        renderStyle.transitionProperty = value;
        break;
      // Others
      case OBJECT_FIT:
        renderStyle.objectFit = value;
        break;
      case OBJECT_POSITION:
        renderStyle.objectPosition = value;
        break;
      case FILTER:
        renderStyle.filter = value;
        break;
      case SLIVER_DIRECTION:
        renderStyle.sliverDirection = value;
          break;
    }
  }

  /// Set internal style value to the element.
  dynamic _resolveRenderStyleValue(String property, dynamic present) {
    dynamic value;
    switch (property) {
      case DISPLAY:
        value = CSSDisplayMixin.resolveDisplay(present);
        break;
      case OVERFLOW_X:
      case OVERFLOW_Y:
        value = CSSOverflowMixin.resolveOverflowType(present);
        break;
      case POSITION:
        value = CSSPositionMixin.resolvePositionType(present);
        break;
      case Z_INDEX:
        value = int.tryParse(present);
        break;
      case TOP:
      case LEFT:
      case BOTTOM:
      case RIGHT:
      case FLEX_BASIS:
      case PADDING_TOP:
      case PADDING_RIGHT:
      case PADDING_BOTTOM:
      case PADDING_LEFT:
      case WIDTH:
      case MIN_WIDTH:
      case MAX_WIDTH:
      case HEIGHT:
      case MIN_HEIGHT:
      case MAX_HEIGHT:
      case MARGIN_LEFT:
      case MARGIN_TOP:
      case MARGIN_RIGHT:
      case MARGIN_BOTTOM:
      case FONT_SIZE:
        value = CSSLength.resolveLength(present, renderStyle, property);
        break;
      case FLEX_DIRECTION:
        value = CSSFlexboxMixin.resolveFlexDirection(present);
        break;
      case FLEX_WRAP:
        value = CSSFlexboxMixin.resolveFlexWrap(present);
        break;
      case ALIGN_CONTENT:
        value = CSSFlexboxMixin.resolveAlignContent(present);
        break;
      case ALIGN_ITEMS:
        value = CSSFlexboxMixin.resolveAlignItems(present);
        break;
      case JUSTIFY_CONTENT:
        value = CSSFlexboxMixin.resolveJustifyContent(present);
        break;
      case ALIGN_SELF:
        value = CSSFlexboxMixin.resolveAlignSelf(present);
        break;
      case FLEX_GROW:
        value = CSSFlexboxMixin.resolveFlexGrow(present);
        break;
      case FLEX_SHRINK:
        value = CSSFlexboxMixin.resolveFlexShrink(present);
        break;
      case SLIVER_DIRECTION:
        value = CSSSliverMixin.resolveAxis(present);
        break;
      case TEXT_ALIGN:
        value = CSSTextMixin.resolveTextAlign(present);
        break;
      case BACKGROUND_ATTACHMENT:
        value = CSSBackground.resolveBackgroundAttachment(present);
        break;
      case BACKGROUND_IMAGE:
        value = CSSBackground.resolveBackgroundImage(present, renderStyle, property, elementManager.controller);
        break;
      case BACKGROUND_REPEAT:
        value = CSSBackground.resolveBackgroundRepeat(present);
        break;
      case BACKGROUND_POSITION_X:
        value = CSSPosition.resolveBackgroundPosition(present, renderStyle, property, true);
        break;
      case BACKGROUND_POSITION_Y:
        value = CSSPosition.resolveBackgroundPosition(present, renderStyle, property, false);
        break;
      case BACKGROUND_SIZE:
        value = CSSBackground.resolveBackgroundSize(present, renderStyle, property);
        break;
      case BACKGROUND_CLIP:
        value = CSSBackground.resolveBackgroundClip(present);
        break;
      case BACKGROUND_ORIGIN:
        value = CSSBackground.resolveBackgroundOrigin(present);
        break;
      case BORDER_LEFT_WIDTH:
      case BORDER_TOP_WIDTH:
      case BORDER_RIGHT_WIDTH:
      case BORDER_BOTTOM_WIDTH:
        value = CSSBorderSide.resolveBorderWidth(present, renderStyle, property);
        break;
      case BORDER_LEFT_STYLE:
      case BORDER_TOP_STYLE:
      case BORDER_RIGHT_STYLE:
      case BORDER_BOTTOM_STYLE:
        value = CSSBorderSide.resolveBorderStyle(present);
        break;
      case COLOR:
      case BACKGROUND_COLOR:
      case TEXT_DECORATION_COLOR:
      case BORDER_LEFT_COLOR:
      case BORDER_TOP_COLOR:
      case BORDER_RIGHT_COLOR:
      case BORDER_BOTTOM_COLOR:
        value = CSSColor.resolveColor(present, renderStyle, property);
        break;
      case BOX_SHADOW:
        value = CSSBoxShadow.parseBoxShadow(present, renderStyle, property);
        break;
      case BORDER_TOP_LEFT_RADIUS:
      case BORDER_TOP_RIGHT_RADIUS:
      case BORDER_BOTTOM_LEFT_RADIUS:
      case BORDER_BOTTOM_RIGHT_RADIUS:
        value = CSSBorderRadius.parseBorderRadius(present, renderStyle, property);
        break;
      case OPACITY:
        value = CSSOpacityMixin.resolveOpacity(present);
        break;
      case VISIBILITY:
        value = CSSVisibilityMixin.resolveVisibility(present);
        break;
      case CONTENT_VISIBILITY:
        value = CSSContentVisibilityMixin.resolveContentVisibility(present);
        break;
      case TRANSFORM:
        value = CSSTransformMixin.resolveTransform(present);
        break;
      case FILTER:
        value = CSSFunction.parseFunction(present);
        break;
      case TRANSFORM_ORIGIN:
        value = CSSOrigin.parseOrigin(present, renderStyle, property);
        break;
      case OBJECT_FIT:
        value = CSSObjectFitMixin.resolveBoxFit(present);
        break;
      case OBJECT_POSITION:
        value = CSSObjectPositionMixin.resolveObjectPosition(present);
        break;
      case TEXT_DECORATION_LINE:
        value = CSSText.resolveTextDecorationLine(present);
        break;
      case TEXT_DECORATION_STYLE:
        value = CSSText.resolveTextDecorationStyle(present);
        break;
      case FONT_WEIGHT:
        value = CSSText.resolveFontWeight(present);
        break;
      case FONT_STYLE:
        value = CSSText.resolveFontStyle(present);
        break;
      case FONT_FAMILY:
        value = CSSText.resolveFontFamilyFallback(present);
        break;
      case LINE_HEIGHT:
        value = CSSText.resolveLineHeight(present, renderStyle, property);
        break;
      case LETTER_SPACING:
        value = CSSText.resolveSpacing(present, renderStyle, property);
        break;
      case WORD_SPACING:
        value = CSSText.resolveSpacing(present, renderStyle, property);
        break;
      case TEXT_SHADOW:
        value = CSSText.resolveTextShadow(present, renderStyle, property);
        break;
      case WHITE_SPACE:
        value = CSSText.resolveWhiteSpace(present);
        break;
      case TEXT_OVERFLOW:
        // Overflow will affect text-overflow ellipsis taking effect
        value = CSSText.resolveTextOverflow(present);
        break;
      case LINE_CLAMP:
        value = CSSText.parseLineClamp(present);
        break;
      case VERTICAL_ALIGN:
        value = CSSInlineMixin.resolveVerticalAlign(present);
        break;
      // Transition
      case TRANSITION_DELAY:
      case TRANSITION_DURATION:
      case TRANSITION_TIMING_FUNCTION:
      case TRANSITION_PROPERTY:
        value = CSSStyleProperty.getMultipleValues(present);
        break;
    }

    return value;
  }

  void setRenderStyle(String property, String present) {
    dynamic value = present.isEmpty ? null : _resolveRenderStyleValue(property, present);
    setRenderStyleProperty(property, value);
  }

  void _updateColorRelativePropertyWithColor(Element element) {
    RenderStyle renderStyle = element.renderStyle;
    renderStyle.updateColorRelativeProperty();
    if (element.children.isNotEmpty) {
      element.children.forEach((Element child) {
        if (!child.renderStyle.hasColor) {
          _updateColorRelativePropertyWithColor(child);
        }
      });
    }
  }

  void _updateFontRelativeLengthWithFontSize() {
    // Update all the children's length value.
    _updateChildrenFontRelativeLength(this);

    if (renderBoxModel!.isDocumentRootBox) {
      // Update all the document tree.
      _updateChildrenRootFontRelativeLength(this);
    }
  }

  void _updateChildrenFontRelativeLength(Element element) {
    RenderStyle renderStyle = element.renderStyle;
    renderStyle.updateFontRelativeLength();
    if (element.children.isNotEmpty) {
      element.children.forEach((Element child) {
        if (!child.renderStyle.hasFontSize) {
          _updateChildrenFontRelativeLength(child);
        }
      });
    }
  }

  void _updateChildrenRootFontRelativeLength(Element element) {
    RenderStyle renderStyle = element.renderStyle;
    renderStyle.updateRootFontRelativeLength();
    if (element.children.isNotEmpty) {
      element.children.forEach((Element child) {
        _updateChildrenRootFontRelativeLength(child);
      });
    }
  }

  void _applyDefaultStyle(CSSStyleDeclaration style) {
    if (_defaultStyle.isNotEmpty) {
      _defaultStyle.forEach((propertyName, dynamic value) {
        style.setProperty(propertyName, value);
      });
    }
  }

  void _applyInlineStyle(CSSStyleDeclaration style) {
    if (inlineStyle.isNotEmpty) {
      inlineStyle.forEach((propertyName, dynamic value) {
        // Force inline style to be applied as important priority.
        style.setProperty(propertyName, value, true);
      });
    }
  }

  void _applySheetStyle(CSSStyleDeclaration style) {
    if (classList.isNotEmpty) {
      const String classSelectorPrefix = '.';
      for (String className in classList) {
        for (CSSStyleSheet sheet in elementManager.styleSheets) {
          List<CSSRule> rules = sheet.cssRules;
          for (int i = 0; i < rules.length; i++) {
            CSSRule rule = rules[i];
            if (rule is CSSStyleRule && rule.selectorText == (classSelectorPrefix + className)) {
              var sheetStyle = rule.style;
              for (String propertyName in sheetStyle.keys) {
                style.setProperty(propertyName, sheetStyle[propertyName], false);
              }
            }
          }
        }
      }
    }
  }

  void _onStyleChanged(String propertyName, String? prevValue, String currentValue) {
    if (renderStyle.shouldTransition(propertyName, prevValue, currentValue)) {
      renderStyle.runTransition(propertyName, prevValue, currentValue);
    } else {
      setRenderStyle(propertyName, currentValue);
    }
  }

  // Set inline style property.
  void setInlineStyle(String property, dynamic value) {
    // Current only for mark property is setting by inline style.
    inlineStyle[property] = value;
    style.setProperty(property, value, true);
  }

  void _applyStyle(CSSStyleDeclaration style) {
    // Apply default style.
    _applyDefaultStyle(style);
    // Init display from style directly cause renderStyle is not flushed yet.
    renderStyle.initDisplay();

    _applyInlineStyle(style);
    _applySheetStyle(style);
  }

  void recalculateStyle() {
    // TODO: current only support class selector in stylesheet
    if (renderBoxModel != null && classList.isNotEmpty) {
      // Diff style.
      CSSStyleDeclaration newStyle = CSSStyleDeclaration();
      _applyStyle(newStyle);
      Map<String, String?> diffs = style.diff(newStyle);
      if (diffs.isNotEmpty) {
        // Update render style.
        diffs.forEach((String propertyName, String? value) {
          style.setProperty(propertyName, value);
        });
        style.flushPendingProperties();
      }
    }
  }

  void recalculateNestedStyle() {
    recalculateStyle();
    // Update children style.
    children.forEach((Element child) {
      child.recalculateNestedStyle();
    });
  }

  @mustCallSuper
  void setProperty(String key, dynamic value) {
    if (value == null || value == EMPTY_STRING) {
      return removeProperty(key);
    }

    if (key == _CLASS_NAME) {
      className = value;
    } else {
      properties[key] = value;
    }
  }

  @mustCallSuper
  dynamic getProperty(String key) {
    if (key == _CLASS_NAME) {
      return className;
    } else {
      return properties[key];
    }
  }

  @mustCallSuper
  void removeProperty(String key) {
    if (key == _STYLE_PROPERTY) {
      _removeInlineStyle();
    } else if (key == _CLASS_NAME) {
      className = EMPTY_STRING;
    } else {
      properties.remove(key);
    }
  }

  void _removeInlineStyle() {
    inlineStyle.forEach((String property, _) {
      _removeInlineStyleProperty(property);
    });
    style.flushPendingProperties();
  }

  void _removeInlineStyleProperty(String property) {
    inlineStyle.remove(property);
    style.removeProperty(property, true);
  }

  BoundingClientRect get boundingClientRect {
    BoundingClientRect boundingClientRect = BoundingClientRect(0, 0, 0, 0, 0, 0, 0, 0);
    if (isRendererAttached) {
      RenderBox sizedBox = renderBoxModel!;
      // Force flush layout.
      if (!sizedBox.hasSize) {
        sizedBox.markNeedsLayout();
        sizedBox.owner!.flushLayout();
      }

      if (sizedBox.hasSize) {
        Offset offset = getOffset(sizedBox);
        Size size = sizedBox.size;
        boundingClientRect = BoundingClientRect(
          offset.dx,
          offset.dy,
          size.width,
          size.height,
          offset.dy,
          offset.dx + size.width,
          offset.dy + size.height,
          offset.dx);
      }
    }

    return boundingClientRect;
  }

  double getOffsetX() {
    double offset = 0;
    RenderBoxModel selfRenderBoxModel = renderBoxModel!;
    if (selfRenderBoxModel.attached) {
      Offset relative = getOffset(selfRenderBoxModel);
      offset += relative.dx;
    }
    return offset;
  }

  double getOffsetY() {
    double offset = 0;
    RenderBoxModel selfRenderBoxModel = renderBoxModel!;
    if (selfRenderBoxModel.attached) {
      Offset relative = getOffset(selfRenderBoxModel);
      offset += relative.dy;
    }
    return offset;
  }

  Offset getOffset(RenderBox renderBox) {
    // Need to flush layout to get correct size.
    elementManager
        .getRootRenderBox()
        .owner!
        .flushLayout();

    Element? element = _findContainingBlock(this);
    element ??= elementManager.viewportElement;
    return renderBox.localToGlobal(Offset.zero, ancestor: element.renderBoxModel);
  }

  void _ensureEventResponderBound() {
    // Must bind event responder on render box model whatever there is no event listener.
    RenderBoxModel? selfRenderBoxModel = renderBoxModel;
    if (selfRenderBoxModel != null) {
      // Make sure pointer responder bind.
      addEventResponder(selfRenderBoxModel);
      if (_hasIntersectionObserverEvent(eventHandlers)) {
        selfRenderBoxModel.addIntersectionChangeListener(handleIntersectionChange);
      }
    }
  }

  void addEvent(String eventType) {
    if (eventHandlers.containsKey(eventType)) return; // Only listen once.
    addEventListener(eventType, dispatchEvent);
    _ensureEventResponderBound();
  }

  void removeEvent(String eventType) {
    if (!eventHandlers.containsKey(eventType)) return; // Only listen once.
    removeEventListener(eventType, dispatchEvent);

    RenderBoxModel? selfRenderBoxModel = renderBoxModel;
    if (selfRenderBoxModel != null) {
      if (eventHandlers.isEmpty) {
        // Remove pointer responder if there is no event handler.
        removeEventResponder(selfRenderBoxModel);
      }

      // Remove listener when no intersection related event
      if (_isIntersectionObserverEvent(eventType) && !_hasIntersectionObserverEvent(eventHandlers)) {
        selfRenderBoxModel.removeIntersectionChangeListener(handleIntersectionChange);
      }
    }
  }

  void handleMethodClick() {
    Event clickEvent = MouseEvent(EVENT_CLICK, MouseEventInit(bubbles: true, cancelable: true));
    // If element not in tree, click is fired and only response to itself.
    dispatchEvent(clickEvent);
  }

  Future<Uint8List> toBlob({ double? devicePixelRatio }) {
    devicePixelRatio ??= window.devicePixelRatio;

    Completer<Uint8List> completer = Completer();
    if (targetId != HTML_ID) {
      convertToRepaintBoundary();
    }
    renderBoxModel!.owner!.flushLayout();

    SchedulerBinding.instance!.addPostFrameCallback((_) async {
      Uint8List captured;
      RenderBoxModel? renderObject = targetId == HTML_ID
          ? elementManager.viewportElement.renderBoxModel
          : renderBoxModel;
      if (renderObject!.hasSize && renderObject.size.isEmpty) {
        // Return a blob with zero length.
        captured = Uint8List(0);
      } else {
        Image image = await renderObject.toImage(pixelRatio: devicePixelRatio!);
        ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
        captured = byteData!.buffer.asUint8List();
      }

      completer.complete(captured);
    });
    SchedulerBinding.instance!.scheduleFrame();

    return completer.future;
  }

  void debugHighlight() {
    if (isRendererAttached) {
      renderBoxModel?.debugShouldPaintOverlay = true;
    }
  }

  void debugHideHighlight() {
    if (isRendererAttached) {
      renderBoxModel?.debugShouldPaintOverlay = false;
    }
  }

  // Create a new RenderLayoutBox for the scrolling content.
  RenderLayoutBox createScrollingContentLayout() {
    // FIXME: Create a empty renderStyle for do not share renderStyle with element. Current update here will break flexbox.
    RenderStyle scrollingContentRenderStyle = RenderStyle(target: this);
    RenderLayoutBox scrollingContentLayoutBox = _createRenderLayout(
      repaintSelf: true,
      renderStyle: scrollingContentRenderStyle,
    );
    style.addStyleChangeListener(scrollingContentBoxStyleListener);
    scrollingContentLayoutBox.isScrollingContentBox = true;
    return scrollingContentLayoutBox;
  }

  RenderLayoutBox _createRenderLayout({
      RenderLayoutBox? prevRenderLayoutBox,
      RenderStyle? renderStyle,
      bool repaintSelf = false
  }) {
    CSSDisplay display = this.renderStyle.display;
    renderStyle ??= this.renderStyle;

    if (display == CSSDisplay.flex || display == CSSDisplay.inlineFlex) {
      RenderFlexLayout? flexLayout;

      if (prevRenderLayoutBox == null) {
        if (repaintSelf) {
          flexLayout = RenderSelfRepaintFlexLayout(
            renderStyle: renderStyle,
          );
        } else {
          flexLayout = RenderFlexLayout(
            renderStyle: renderStyle,
          );
        }
      } else if (prevRenderLayoutBox is RenderFlowLayout) {
        if (prevRenderLayoutBox is RenderSelfRepaintFlowLayout) {
          if (repaintSelf) {
            // RenderSelfRepaintFlowLayout --> RenderSelfRepaintFlexLayout
            flexLayout = prevRenderLayoutBox.toFlexLayout();
          } else {
            // RenderSelfRepaintFlowLayout --> RenderFlexLayout
            flexLayout = prevRenderLayoutBox.toParentRepaintFlexLayout();
          }
        } else {
          if (repaintSelf) {
            // RenderFlowLayout --> RenderSelfRepaintFlexLayout
            flexLayout = prevRenderLayoutBox.toSelfRepaintFlexLayout();
          } else {
            // RenderFlowLayout --> RenderFlexLayout
            flexLayout = prevRenderLayoutBox.toFlexLayout();
          }
        }
      } else if (prevRenderLayoutBox is RenderFlexLayout) {
        if (prevRenderLayoutBox is RenderSelfRepaintFlexLayout) {
          if (repaintSelf) {
            // RenderSelfRepaintFlexLayout --> RenderSelfRepaintFlexLayout
            flexLayout = prevRenderLayoutBox;
            return flexLayout;
          } else {
            // RenderSelfRepaintFlexLayout --> RenderFlexLayout
            flexLayout = prevRenderLayoutBox.toParentRepaint();
          }
        } else {
          if (repaintSelf) {
            // RenderFlexLayout --> RenderSelfRepaintFlexLayout
            flexLayout = prevRenderLayoutBox.toSelfRepaint();
          } else {
            // RenderFlexLayout --> RenderFlexLayout
            flexLayout = prevRenderLayoutBox;
            return flexLayout;
          }
        }
      } else if (prevRenderLayoutBox is RenderSliverListLayout) {
        flexLayout = prevRenderLayoutBox.toFlexLayout();
      }

      return flexLayout!;
    } else if (display == CSSDisplay.block ||
      display == CSSDisplay.none ||
      display == CSSDisplay.inline ||
      display == CSSDisplay.inlineBlock) {
      RenderFlowLayout? flowLayout;

      if (prevRenderLayoutBox == null) {
        if (repaintSelf) {
          flowLayout = RenderSelfRepaintFlowLayout(
            renderStyle: renderStyle,
          );
        } else {
          flowLayout = RenderFlowLayout(
            renderStyle: renderStyle,
          );
        }
      } else if (prevRenderLayoutBox is RenderFlowLayout) {
        if (prevRenderLayoutBox is RenderSelfRepaintFlowLayout) {
          if (repaintSelf) {
            // RenderSelfRepaintFlowLayout --> RenderSelfRepaintFlowLayout
            flowLayout = prevRenderLayoutBox;
            return flowLayout;
          } else {
            // RenderSelfRepaintFlowLayout --> RenderFlowLayout
            flowLayout = prevRenderLayoutBox.toParentRepaint();
          }
        } else {
          if (repaintSelf) {
            // RenderFlowLayout --> RenderSelfRepaintFlowLayout
            flowLayout = prevRenderLayoutBox.toSelfRepaint();
          } else {
            // RenderFlowLayout --> RenderFlowLayout
            flowLayout = prevRenderLayoutBox;
            return flowLayout;
          }
        }
      } else if (prevRenderLayoutBox is RenderFlexLayout) {
        if (prevRenderLayoutBox is RenderSelfRepaintFlexLayout) {
          if (repaintSelf) {
            // RenderSelfRepaintFlexLayout --> RenderSelfRepaintFlowLayout
            flowLayout = prevRenderLayoutBox.toFlowLayout();
          } else {
            // RenderSelfRepaintFlexLayout --> RenderFlowLayout
            flowLayout = prevRenderLayoutBox.toParentRepaintFlowLayout();
          }
        } else {
          if (repaintSelf) {
            // RenderFlexLayout --> RenderSelfRepaintFlowLayout
            flowLayout = prevRenderLayoutBox.toSelfRepaintFlowLayout();
          } else {
            // RenderFlexLayout --> RenderFlowLayout
            flowLayout = prevRenderLayoutBox.toFlowLayout();
          }
        }
      } else if (prevRenderLayoutBox is RenderSliverListLayout) {
        // RenderRecyclerLayout --> RenderFlowLayout
        flowLayout = prevRenderLayoutBox.toFlowLayout();
      }

      return flowLayout!;
    } else if (display == CSSDisplay.sliver) {
      late RenderSliverListLayout renderSliverListLayout;

      if (prevRenderLayoutBox == null) {
        ElementSliverBoxChildManager manager = ElementSliverBoxChildManager(this);
        renderSliverListLayout = RenderSliverListLayout(
          renderStyle: renderStyle,
          manager: manager,
          onScroll: _handleScroll,
        );
        manager.setupSliverLayoutLayout(renderSliverListLayout);
      } else if (prevRenderLayoutBox is RenderFlowLayout
          || prevRenderLayoutBox is RenderFlexLayout) {
        ElementSliverBoxChildManager manager = ElementSliverBoxChildManager(this);
        renderSliverListLayout = RenderSliverListLayout(
          renderStyle: renderStyle,
          manager: manager,
          onScroll: _handleScroll,
        );
        manager.setupSliverLayoutLayout(renderSliverListLayout);
        renderSliverListLayout.addAll(prevRenderLayoutBox.getDetachedChildrenAsList() as List<RenderBox>);
        renderSliverListLayout = prevRenderLayoutBox.copyWith(renderSliverListLayout);
      } else if (prevRenderLayoutBox is RenderSliverListLayout) {
        renderSliverListLayout = prevRenderLayoutBox;
      }

      return renderSliverListLayout;
    } else {
      throw FlutterError('Not supported display type $display');
    }
  }

  RenderIntrinsic _createRenderIntrinsic({
    RenderIntrinsic? prevRenderIntrinsic,
    bool repaintSelf = false
  }) {
    RenderIntrinsic intrinsic;

    if (prevRenderIntrinsic == null) {
      if (repaintSelf) {
        intrinsic = RenderSelfRepaintIntrinsic(
          renderStyle,
        );
      } else {
        intrinsic = RenderIntrinsic(
          renderStyle,
        );
      }
    } else {
      if (prevRenderIntrinsic is RenderSelfRepaintIntrinsic) {
        if (repaintSelf) {
          // RenderSelfRepaintIntrinsic --> RenderSelfRepaintIntrinsic
          intrinsic = prevRenderIntrinsic;
        } else {
          // RenderSelfRepaintIntrinsic --> RenderIntrinsic
          intrinsic = prevRenderIntrinsic.toParentRepaint();
        }
      } else {
        if (repaintSelf) {
          // RenderIntrinsic --> RenderSelfRepaintIntrinsic
          intrinsic = prevRenderIntrinsic.toSelfRepaint();
        } else {
          // RenderIntrinsic --> RenderIntrinsic
          intrinsic = prevRenderIntrinsic;
        }
      }
    }
    return intrinsic;
  }

  void _updateRenderBoxModelWithZIndex() {
    // Needs to sort children when parent paint children
    if (renderBoxModel!.parentData is RenderLayoutParentData) {
      RenderLayoutBox parent = renderBoxModel!.parent as RenderLayoutBox;
      final RenderLayoutParentData parentData = renderBoxModel!.parentData as RenderLayoutParentData;
      RenderBox? nextSibling = parentData.nextSibling;

      parent.sortedChildren.remove(renderBoxModel);
      parent.insertChildIntoSortedChildren(renderBoxModel!, after: nextSibling);
    }
  }
}

Element? _findContainingBlock(Element element) {
  Element? _el = element.parentElement;
  Element rootEl = element.elementManager.viewportElement;

  while (_el != null) {
    bool isElementNonStatic = _el.renderStyle.position != CSSPositionType.static;
    bool hasTransform = _el.renderStyle.transform != null;
    // https://www.w3.org/TR/CSS2/visudet.html#containing-block-details
    if (_el == rootEl || isElementNonStatic || hasTransform) {
      break;
    }
    _el = _el.parent as Element?;
  }
  return _el;
}

bool _isIntersectionObserverEvent(String eventType) {
  return eventType == EVENT_APPEAR || eventType == EVENT_DISAPPEAR || eventType == EVENT_INTERSECTION_CHANGE;
}

bool _hasIntersectionObserverEvent(Map eventHandlers) {
  return eventHandlers.containsKey('appear') ||
      eventHandlers.containsKey('disappear') ||
      eventHandlers.containsKey('intersectionchange');
}

class BoundingClientRect {
  final double x;
  final double y;
  final double width;
  final double height;
  final double top;
  final double right;
  final double bottom;
  final double left;

  BoundingClientRect(this.x, this.y, this.width, this.height, this.top, this.right, this.bottom, this.left);

  Pointer<NativeBoundingClientRect> toNative() {
    Pointer<NativeBoundingClientRect> nativeBoundingClientRect = malloc.allocate<NativeBoundingClientRect>(sizeOf<NativeBoundingClientRect>());
    nativeBoundingClientRect.ref.width = width;
    nativeBoundingClientRect.ref.height = height;
    nativeBoundingClientRect.ref.x = x;
    nativeBoundingClientRect.ref.y = y;
    nativeBoundingClientRect.ref.top = top;
    nativeBoundingClientRect.ref.right = right;
    nativeBoundingClientRect.ref.left = left;
    nativeBoundingClientRect.ref.bottom = bottom;
    return nativeBoundingClientRect;
  }

  Map<String, dynamic> toJSON() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom
    };
  }
}

void _setPositionedChildParentData(RenderLayoutBox parentRenderLayoutBox, Element child) {
  RenderLayoutParentData parentData = RenderLayoutParentData();
  RenderBoxModel childRenderBoxModel = child.renderBoxModel!;
  childRenderBoxModel.parentData = CSSPositionedLayout.getPositionParentData(childRenderBoxModel, parentData);
}
