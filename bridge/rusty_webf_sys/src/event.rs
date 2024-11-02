// Generated by WebF TSDL, don't edit this file directly.
// Generate command: node scripts/generate_binding_code.js
/*
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/
use std::ffi::*;
use crate::*;
#[repr(C)]
enum EventType {
  Event = 0,
  CustomEvent = 1,
  AnimationEvent = 2,
  CloseEvent = 3,
  GestureEvent = 4,
  HashchangeEvent = 5,
  IntersectionChangeEvent = 6,
  TransitionEvent = 7,
  UIEvent = 8,
  FocusEvent = 9,
  InputEvent = 10,
  MouseEvent = 11,
  PointerEvent = 12,
}
#[repr(C)]
pub struct EventRustMethods {
  pub version: c_double,
  pub bubbles: extern "C" fn(ptr: *const OpaquePtr) -> i32,
  pub cancel_bubble: extern "C" fn(ptr: *const OpaquePtr) -> i32,
  pub set_cancel_bubble: extern "C" fn(ptr: *const OpaquePtr, value: i32, exception_state: *const OpaquePtr) -> bool,
  pub cancelable: extern "C" fn(ptr: *const OpaquePtr) -> i32,
  pub current_target: extern "C" fn(ptr: *const OpaquePtr) -> RustValue<EventTargetRustMethods>,
  pub default_prevented: extern "C" fn(ptr: *const OpaquePtr) -> i32,
  pub src_element: extern "C" fn(ptr: *const OpaquePtr) -> RustValue<EventTargetRustMethods>,
  pub target: extern "C" fn(ptr: *const OpaquePtr) -> RustValue<EventTargetRustMethods>,
  pub is_trusted: extern "C" fn(ptr: *const OpaquePtr) -> i32,
  pub time_stamp: extern "C" fn(ptr: *const OpaquePtr) -> c_double,
  pub type_: extern "C" fn(ptr: *const OpaquePtr) -> *const c_char,
  pub dup_type: extern "C" fn(ptr: *const OpaquePtr) -> *const c_char,
  pub init_event: extern "C" fn(ptr: *const OpaquePtr, *const c_char, i32, i32, exception_state: *const OpaquePtr) -> c_void,
  pub prevent_default: extern "C" fn(ptr: *const OpaquePtr, exception_state: *const OpaquePtr) -> c_void,
  pub stop_immediate_propagation: extern "C" fn(ptr: *const OpaquePtr, exception_state: *const OpaquePtr) -> c_void,
  pub stop_propagation: extern "C" fn(ptr: *const OpaquePtr, exception_state: *const OpaquePtr) -> c_void,
  pub release: extern "C" fn(ptr: *const OpaquePtr) -> c_void,
  pub dynamic_to: extern "C" fn(ptr: *const OpaquePtr, type_: EventType) -> RustValue<c_void>,
}
pub struct Event {
  pub ptr: *const OpaquePtr,
  context: *const ExecutingContext,
  method_pointer: *const EventRustMethods,
  status: *const RustValueStatus
}
impl Event {
  pub fn initialize(ptr: *const OpaquePtr, context: *const ExecutingContext, method_pointer: *const EventRustMethods, status: *const RustValueStatus) -> Event {
    Event {
      ptr,
      context,
      method_pointer,
      status
    }
  }
  pub fn ptr(&self) -> *const OpaquePtr {
    self.ptr
  }
  pub fn context<'a>(&self) -> &'a ExecutingContext {
    assert!(!self.context.is_null(), "Context PTR must not be null");
    unsafe { &*self.context }
  }
  pub fn bubbles(&self) -> bool {
    let value = unsafe {
      ((*self.method_pointer).bubbles)(self.ptr())
    };
    value != 0
  }
  pub fn cancel_bubble(&self) -> bool {
    let value = unsafe {
      ((*self.method_pointer).cancel_bubble)(self.ptr())
    };
    value != 0
  }
  pub fn set_cancel_bubble(&self, value: bool, exception_state: &ExceptionState) -> Result<(), String> {
    unsafe {
      ((*self.method_pointer).set_cancel_bubble)(self.ptr(), i32::from(value), exception_state.ptr)
    };
    if exception_state.has_exception() {
      return Err(exception_state.stringify(self.context()));
    }
    Ok(())
  }
  pub fn cancelable(&self) -> bool {
    let value = unsafe {
      ((*self.method_pointer).cancelable)(self.ptr())
    };
    value != 0
  }
  pub fn current_target(&self) -> EventTarget {
    let value = unsafe {
      ((*self.method_pointer).current_target)(self.ptr())
    };
    EventTarget::initialize(value.value, self.context(), value.method_pointer, value.status)
  }
  pub fn default_prevented(&self) -> bool {
    let value = unsafe {
      ((*self.method_pointer).default_prevented)(self.ptr())
    };
    value != 0
  }
  pub fn src_element(&self) -> EventTarget {
    let value = unsafe {
      ((*self.method_pointer).src_element)(self.ptr())
    };
    EventTarget::initialize(value.value, self.context(), value.method_pointer, value.status)
  }
  pub fn target(&self) -> EventTarget {
    let value = unsafe {
      ((*self.method_pointer).target)(self.ptr())
    };
    EventTarget::initialize(value.value, self.context(), value.method_pointer, value.status)
  }
  pub fn is_trusted(&self) -> bool {
    let value = unsafe {
      ((*self.method_pointer).is_trusted)(self.ptr())
    };
    value != 0
  }
  pub fn time_stamp(&self) -> f64 {
    let value = unsafe {
      ((*self.method_pointer).time_stamp)(self.ptr())
    };
    value
  }
  pub fn type_(&self) -> String {
    let value = unsafe {
      ((*self.method_pointer).type_)(self.ptr())
    };
    let value = unsafe { std::ffi::CStr::from_ptr(value) };
    value.to_str().unwrap().to_string()
  }
  pub fn init_event(&self, type_: &str, bubbles: bool, cancelable: bool, exception_state: &ExceptionState) -> Result<(), String> {
    unsafe {
      ((*self.method_pointer).init_event)(self.ptr(), CString::new(type_).unwrap().as_ptr(), i32::from(bubbles), i32::from(cancelable), exception_state.ptr);
    };
    if exception_state.has_exception() {
      return Err(exception_state.stringify(self.context()));
    }
    Ok(())
  }
  pub fn prevent_default(&self, exception_state: &ExceptionState) -> Result<(), String> {
    unsafe {
      ((*self.method_pointer).prevent_default)(self.ptr(), exception_state.ptr);
    };
    if exception_state.has_exception() {
      return Err(exception_state.stringify(self.context()));
    }
    Ok(())
  }
  pub fn stop_immediate_propagation(&self, exception_state: &ExceptionState) -> Result<(), String> {
    unsafe {
      ((*self.method_pointer).stop_immediate_propagation)(self.ptr(), exception_state.ptr);
    };
    if exception_state.has_exception() {
      return Err(exception_state.stringify(self.context()));
    }
    Ok(())
  }
  pub fn stop_propagation(&self, exception_state: &ExceptionState) -> Result<(), String> {
    unsafe {
      ((*self.method_pointer).stop_propagation)(self.ptr(), exception_state.ptr);
    };
    if exception_state.has_exception() {
      return Err(exception_state.stringify(self.context()));
    }
    Ok(())
  }
  pub fn as_custom_event(&self) -> Result<CustomEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::CustomEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the CustomEvent type.");
    }
    Ok(CustomEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const CustomEventRustMethods, raw_ptr.status))
  }
  pub fn as_animation_event(&self) -> Result<AnimationEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::AnimationEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the AnimationEvent type.");
    }
    Ok(AnimationEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const AnimationEventRustMethods, raw_ptr.status))
  }
  pub fn as_close_event(&self) -> Result<CloseEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::CloseEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the CloseEvent type.");
    }
    Ok(CloseEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const CloseEventRustMethods, raw_ptr.status))
  }
  pub fn as_gesture_event(&self) -> Result<GestureEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::GestureEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the GestureEvent type.");
    }
    Ok(GestureEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const GestureEventRustMethods, raw_ptr.status))
  }
  pub fn as_hashchange_event(&self) -> Result<HashchangeEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::HashchangeEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the HashchangeEvent type.");
    }
    Ok(HashchangeEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const HashchangeEventRustMethods, raw_ptr.status))
  }
  pub fn as_intersection_change_event(&self) -> Result<IntersectionChangeEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::IntersectionChangeEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the IntersectionChangeEvent type.");
    }
    Ok(IntersectionChangeEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const IntersectionChangeEventRustMethods, raw_ptr.status))
  }
  pub fn as_transition_event(&self) -> Result<TransitionEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::TransitionEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the TransitionEvent type.");
    }
    Ok(TransitionEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const TransitionEventRustMethods, raw_ptr.status))
  }
  pub fn as_ui_event(&self) -> Result<UIEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::UIEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the UIEvent type.");
    }
    Ok(UIEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const UIEventRustMethods, raw_ptr.status))
  }
  pub fn as_focus_event(&self) -> Result<FocusEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::FocusEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the FocusEvent type.");
    }
    Ok(FocusEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const FocusEventRustMethods, raw_ptr.status))
  }
  pub fn as_input_event(&self) -> Result<InputEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::InputEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the InputEvent type.");
    }
    Ok(InputEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const InputEventRustMethods, raw_ptr.status))
  }
  pub fn as_mouse_event(&self) -> Result<MouseEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::MouseEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the MouseEvent type.");
    }
    Ok(MouseEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const MouseEventRustMethods, raw_ptr.status))
  }
  pub fn as_pointer_event(&self) -> Result<PointerEvent, &str> {
    let raw_ptr = unsafe {
      assert!(!(*((*self).status)).disposed, "The underline C++ impl of this ptr({:?}) had been disposed", (self.method_pointer));
      ((*self.method_pointer).dynamic_to)(self.ptr, EventType::PointerEvent)
    };
    if (raw_ptr.value == std::ptr::null()) {
      return Err("The type value of Event does not belong to the PointerEvent type.");
    }
    Ok(PointerEvent::initialize(raw_ptr.value, self.context, raw_ptr.method_pointer as *const PointerEventRustMethods, raw_ptr.status))
  }
}
impl Drop for Event {
  fn drop(&mut self) {
    unsafe {
      ((*self.method_pointer).release)(self.ptr());
    }
  }
}
pub trait EventMethods {
  fn bubbles(&self) -> bool;
  fn cancel_bubble(&self) -> bool;
  fn set_cancel_bubble(&self, value: bool, exception_state: &ExceptionState) -> Result<(), String>;
  fn cancelable(&self) -> bool;
  fn current_target(&self) -> EventTarget;
  fn default_prevented(&self) -> bool;
  fn src_element(&self) -> EventTarget;
  fn target(&self) -> EventTarget;
  fn is_trusted(&self) -> bool;
  fn time_stamp(&self) -> f64;
  fn type_(&self) -> String;
  fn init_event(&self, type_: &str, bubbles: bool, cancelable: bool, exception_state: &ExceptionState) -> Result<(), String>;
  fn prevent_default(&self, exception_state: &ExceptionState) -> Result<(), String>;
  fn stop_immediate_propagation(&self, exception_state: &ExceptionState) -> Result<(), String>;
  fn stop_propagation(&self, exception_state: &ExceptionState) -> Result<(), String>;
  fn as_event(&self) -> &Event;
}
impl EventMethods for Event {
  fn bubbles(&self) -> bool {
    self.bubbles()
  }
  fn cancel_bubble(&self) -> bool {
    self.cancel_bubble()
  }
  fn set_cancel_bubble(&self, value: bool, exception_state: &ExceptionState) -> Result<(), String> {
    self.set_cancel_bubble(value, exception_state)
  }
  fn cancelable(&self) -> bool {
    self.cancelable()
  }
  fn current_target(&self) -> EventTarget {
    self.current_target()
  }
  fn default_prevented(&self) -> bool {
    self.default_prevented()
  }
  fn src_element(&self) -> EventTarget {
    self.src_element()
  }
  fn target(&self) -> EventTarget {
    self.target()
  }
  fn is_trusted(&self) -> bool {
    self.is_trusted()
  }
  fn time_stamp(&self) -> f64 {
    self.time_stamp()
  }
  fn type_(&self) -> String {
    self.type_()
  }
  fn init_event(&self, type_: &str, bubbles: bool, cancelable: bool, exception_state: &ExceptionState) -> Result<(), String> {
    self.init_event(type_, bubbles, cancelable, exception_state)
  }
  fn prevent_default(&self, exception_state: &ExceptionState) -> Result<(), String> {
    self.prevent_default(exception_state)
  }
  fn stop_immediate_propagation(&self, exception_state: &ExceptionState) -> Result<(), String> {
    self.stop_immediate_propagation(exception_state)
  }
  fn stop_propagation(&self, exception_state: &ExceptionState) -> Result<(), String> {
    self.stop_propagation(exception_state)
  }
  fn as_event(&self) -> &Event {
    self
  }
}
