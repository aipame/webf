/*
 * Copyright (C) 2020 Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

#ifndef KRAKENBRIDGE_STYLE_DECLARATION_H
#define KRAKENBRIDGE_STYLE_DECLARATION_H

#include "bindings/jsc/DOM/event_target.h"
#include "bindings/jsc/host_class.h"
#include "bindings/jsc/js_context.h"
#include <map>

namespace kraken::binding::jsc {

void bindCSSStyleDeclaration(std::unique_ptr<JSContext> &context);

class CSSStyleDeclaration : public HostClass {
public:
  static CSSStyleDeclaration *instance(JSContext *context);

  JSObjectRef instanceConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount,
                                  const JSValueRef *arguments, JSValueRef *exception) override;

  class StyleDeclarationInstance : public Instance {
  public:
    enum class CSSStyleDeclarationProperty {
      kSetProperty,
      kRemoveProperty,
      kGetPropertyValue
    };
    static std::array<JSStringRef, 3> &getStyleDeclarationPropertyNames();
    static const std::unordered_map<std::string, CSSStyleDeclarationProperty> &getStyleDeclarationPropertyMap();

    StyleDeclarationInstance() = delete;
    StyleDeclarationInstance(CSSStyleDeclaration *cssStyleDeclaration,
                             JSEventTarget::EventTargetInstance *ownerEventTarget);
    ~StyleDeclarationInstance();

    static JSValueRef setProperty(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                  const JSValueRef arguments[], JSValueRef *exception);
    static JSValueRef removeProperty(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception);
    static JSValueRef getPropertyValue(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                       size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception);

    JSValueRef getProperty(std::string &name, JSValueRef *exception) override;
    void setProperty(std::string &name, JSValueRef value, JSValueRef *exception) override;
    void getPropertyNames(JSPropertyNameAccumulatorRef accumulator) override;
    void internalSetProperty(std::string &name, JSValueRef value, JSValueRef *exception);
    void internalRemoveProperty(JSStringRef name, JSValueRef *exception);
    JSValueRef internalGetPropertyValue(JSStringRef name, JSValueRef *exception);

  private:
    std::unordered_map<std::string, JSStringRef> properties;
    const JSEventTarget::EventTargetInstance *ownerEventTarget;

    JSObjectRef _setProperty {nullptr};
    JSObjectRef _getPropertyValue {nullptr};
    JSObjectRef _removeProperty {nullptr};
  };

protected:
  CSSStyleDeclaration() = delete;
  explicit CSSStyleDeclaration(JSContext *context);
};

} // namespace kraken::binding::jsc

#endif // KRAKENBRIDGE_STYLE_DECLARATION_H
