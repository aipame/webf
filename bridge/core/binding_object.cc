/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "binding_object.h"
#include "binding_call_methods.h"
#include "bindings/qjs/exception_state.h"
#include "bindings/qjs/script_promise_resolver.h"
#include "core/executing_context.h"
#include "foundation/native_value_converter.h"

namespace webf {

void NativeBindingObject::HandleCallFromDartSide(NativeBindingObject* binding_object,
                                                 NativeValue* return_value,
                                                 NativeValue* method,
                                                 int32_t argc,
                                                 NativeValue* argv) {
  NativeValue result = binding_object->binding_target_->HandleCallFromDartSide(method, argc, argv);
  if (return_value != nullptr)
    *return_value = result;
}

BindingObject::BindingObject(ExecutingContext* context) : context_(context) {}
BindingObject::~BindingObject() {
  delete binding_object_;
}

BindingObject::BindingObject(ExecutingContext* context, NativeBindingObject* native_binding_object)
    : context_(context) {
  native_binding_object->binding_target_ = this;
  native_binding_object->invoke_binding_methods_from_dart = NativeBindingObject::HandleCallFromDartSide;
  binding_object_ = native_binding_object;
}

NativeValue BindingObject::InvokeBindingMethod(const AtomicString& method,
                                               int32_t argc,
                                               const NativeValue* argv,
                                               ExceptionState& exception_state) const {
  context_->FlushUICommand();
  if (binding_object_->invoke_bindings_methods_from_native == nullptr) {
    exception_state.ThrowException(context_->ctx(), ErrorType::InternalError,
                                   "Failed to call dart method: invokeBindingMethod not initialized.");
    return Native_NewNull();
  }

  NativeValue return_value = Native_NewNull();
  NativeValue native_method = NativeValueConverter<NativeTypeString>::ToNativeValue(method);
  binding_object_->invoke_bindings_methods_from_native(binding_object_, &return_value, &native_method, argc, argv);
  return return_value;
}

NativeValue BindingObject::InvokeBindingMethod(BindingMethodCallOperations binding_method_call_operation,
                                               int32_t argc,
                                               const NativeValue* argv,
                                               ExceptionState& exception_state) const {
  context_->FlushUICommand();
  if (binding_object_->invoke_bindings_methods_from_native == nullptr) {
    exception_state.ThrowException(context_->ctx(), ErrorType::InternalError,
                                   "Failed to call dart method: invokeBindingMethod not initialized.");
    return Native_NewNull();
  }

  NativeValue return_value = Native_NewNull();
  NativeValue native_method = NativeValueConverter<NativeTypeInt64>::ToNativeValue(binding_method_call_operation);
  binding_object_->invoke_bindings_methods_from_native(binding_object_, &return_value, &native_method, argc, argv);
  return return_value;
}

NativeValue BindingObject::GetBindingProperty(const AtomicString& prop, ExceptionState& exception_state) const {
  context_->FlushUICommand();
  const NativeValue argv[] = {Native_NewString(prop.ToNativeString().release())};
  return InvokeBindingMethod(BindingMethodCallOperations::kGetProperty, 1, argv, exception_state);
}

NativeValue BindingObject::SetBindingProperty(const AtomicString& prop,
                                              NativeValue value,
                                              ExceptionState& exception_state) const {
  context_->FlushUICommand();
  const NativeValue argv[] = {Native_NewString(prop.ToNativeString().release()), value};
  return InvokeBindingMethod(BindingMethodCallOperations::kSetProperty, 2, argv, exception_state);
}

ScriptValue BindingObject::AnonymousFunctionCallback(JSContext* ctx,
                                                     const ScriptValue& this_val,
                                                     uint32_t argc,
                                                     const ScriptValue* argv,
                                                     void* private_data) {
  auto id = reinterpret_cast<int64_t>(private_data);
  auto* event_target = toScriptWrappable<EventTarget>(this_val.QJSValue());

  std::vector<NativeValue> arguments;
  arguments.reserve(argc + 1);

  arguments.emplace_back(NativeValueConverter<NativeTypeInt64>::ToNativeValue(id));
  for (int i = 0; i < argc; i++) {
    arguments.emplace_back(argv[i].ToNative());
  }

  ExceptionState exception_state;
  NativeValue result = event_target->InvokeBindingMethod(BindingMethodCallOperations::kAnonymousFunctionCall,
                                                           arguments.size(), arguments.data(), exception_state);

  if (exception_state.HasException()) {
    JSValue error = JS_GetException(ctx);
    event_target->GetExecutingContext()->ReportError(error);
    JS_FreeValue(ctx, error);
    return ScriptValue::Empty(ctx);
  }
  return ScriptValue(ctx, result);
}

struct BindingObjectPromiseContext {
  ExecutingContext* context;
  std::shared_ptr<ScriptPromiseResolver> promise_resolver;
};

void HandleAnonymousAsyncCalledFromDart(void* ptr, NativeValue* native_value, int32_t contextId, const char* errmsg) {
  auto* promise_context = static_cast<BindingObjectPromiseContext*>(ptr);
  if (!promise_context->context->IsValid())
    return;
  if (promise_context->context->contextId() != contextId)
    return;

  auto* context = promise_context->context;

  if (native_value != nullptr) {
    ScriptValue params = ScriptValue(context->ctx(), *native_value);
    promise_context->promise_resolver->Resolve(params.QJSValue());
  } else if (errmsg != nullptr) {
    ExceptionState exception_state;
    exception_state.ThrowException(context->ctx(), ErrorType::TypeError, errmsg);
    JSValue error_object = JS_GetException(context->ctx());
    promise_context->promise_resolver->Reject(error_object);
    JS_FreeValue(context->ctx(), error_object);
  }

  delete promise_context;
}

ScriptValue BindingObject::AnonymousAsyncFunctionCallback(JSContext* ctx,
                                                          const ScriptValue& this_val,
                                                          uint32_t argc,
                                                          const ScriptValue* argv,
                                                          void* private_data) {
  auto id = reinterpret_cast<int64_t>(private_data);
  auto* event_target = toScriptWrappable<EventTarget>(this_val.QJSValue());

  auto promise_resolver = ScriptPromiseResolver::Create(event_target->GetExecutingContext());

  auto* promise_context = new BindingObjectPromiseContext{event_target->GetExecutingContext(), promise_resolver};

  std::vector<NativeValue> arguments;
  arguments.reserve(argc + 4);

  arguments.emplace_back(NativeValueConverter<NativeTypeInt64>::ToNativeValue(id));
  arguments.emplace_back(NativeValueConverter<NativeTypeInt64>::ToNativeValue(event_target->GetExecutingContext()->contextId()));
  arguments.emplace_back(NativeValueConverter<NativeTypePointer<BindingObjectPromiseContext>>::ToNativeValue(promise_context));
  arguments.emplace_back(NativeValueConverter<NativeTypePointer<void>>::ToNativeValue(
      reinterpret_cast<void*>(HandleAnonymousAsyncCalledFromDart)));

  for (int i = 0; i < argc; i++) {
    arguments.emplace_back(argv[i].ToNative());
  }

  ExceptionState exception_state;
  NativeValue result = event_target->InvokeBindingMethod(BindingMethodCallOperations::kAsyncAnonymousFunction,
                                                           argc + 4, arguments.data(), exception_state);
  return ScriptValue(ctx, result);
}

NativeValue BindingObject::GetAllBindingPropertyNames(ExceptionState& exception_state) const {
  context_->FlushUICommand();
  return InvokeBindingMethod(BindingMethodCallOperations::kGetAllPropertyNames, 0, nullptr, exception_state);
}

bool BindingObject::IsEventTarget() const {
  return false;
}

bool BindingObject::IsTouchList() const {
  return false;
}

}  // namespace webf
