// Generated by WebF TSDL, don't edit this file directly.
// Generate command: node scripts/generate_binding_code.js
/*
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/
use std::ffi::*;
use crate::*;
#[repr(C)]
pub struct FocusEventRustMethods {
  pub version: c_double,
  pub ui_event: UIEventRustMethods,
  pub related_target: extern "C" fn(ptr: *const OpaquePtr) -> RustValue<EventTargetRustMethods>,
}
pub struct FocusEvent {
  pub ui_event: UIEvent,
  method_pointer: *const FocusEventRustMethods,
}
impl FocusEvent {
  pub fn initialize(ptr: *const OpaquePtr, context: *const ExecutingContext, method_pointer: *const FocusEventRustMethods, status: *const RustValueStatus) -> FocusEvent {
    unsafe {
      FocusEvent {
        ui_event: UIEvent::initialize(
          ptr,
          context,
          &(method_pointer).as_ref().unwrap().ui_event,
          status,
        ),
        method_pointer,
      }
    }
  }
  pub fn ptr(&self) -> *const OpaquePtr {
    self.ui_event.ptr()
  }
  pub fn context<'a>(&self) -> &'a ExecutingContext {
    self.ui_event.context()
  }
  pub fn related_target(&self) -> EventTarget {
    let value = unsafe {
      ((*self.method_pointer).related_target)(self.ptr())
    };
    EventTarget::initialize(value.value, self.context(), value.method_pointer, value.status)
  }
}
pub trait FocusEventMethods: UIEventMethods {
  fn related_target(&self) -> EventTarget;
  fn as_focus_event(&self) -> &FocusEvent;
}
impl FocusEventMethods for FocusEvent {
  fn related_target(&self) -> EventTarget {
    self.related_target()
  }
  fn as_focus_event(&self) -> &FocusEvent {
    self
  }
}
impl UIEventMethods for FocusEvent {
  fn detail(&self) -> f64 {
    self.ui_event.detail()
  }
  fn view(&self) -> Window {
    self.ui_event.view()
  }
  fn which(&self) -> f64 {
    self.ui_event.which()
  }
  fn as_ui_event(&self) -> &UIEvent {
    &self.ui_event
  }
}
impl EventMethods for FocusEvent {
  fn bubbles(&self) -> bool {
    self.ui_event.event.bubbles()
  }
  fn cancel_bubble(&self) -> bool {
    self.ui_event.event.cancel_bubble()
  }
  fn set_cancel_bubble(&self, value: bool, exception_state: &ExceptionState) -> Result<(), String> {
    self.ui_event.event.set_cancel_bubble(value, exception_state)
  }
  fn cancelable(&self) -> bool {
    self.ui_event.event.cancelable()
  }
  fn current_target(&self) -> EventTarget {
    self.ui_event.event.current_target()
  }
  fn default_prevented(&self) -> bool {
    self.ui_event.event.default_prevented()
  }
  fn src_element(&self) -> EventTarget {
    self.ui_event.event.src_element()
  }
  fn target(&self) -> EventTarget {
    self.ui_event.event.target()
  }
  fn is_trusted(&self) -> bool {
    self.ui_event.event.is_trusted()
  }
  fn time_stamp(&self) -> f64 {
    self.ui_event.event.time_stamp()
  }
  fn type_(&self) -> String {
    self.ui_event.event.type_()
  }
  fn init_event(&self, type_: &str, bubbles: bool, cancelable: bool, exception_state: &ExceptionState) -> Result<(), String> {
    self.ui_event.event.init_event(type_, bubbles, cancelable, exception_state)
  }
  fn prevent_default(&self, exception_state: &ExceptionState) -> Result<(), String> {
    self.ui_event.event.prevent_default(exception_state)
  }
  fn stop_immediate_propagation(&self, exception_state: &ExceptionState) -> Result<(), String> {
    self.ui_event.event.stop_immediate_propagation(exception_state)
  }
  fn stop_propagation(&self, exception_state: &ExceptionState) -> Result<(), String> {
    self.ui_event.event.stop_propagation(exception_state)
  }
  fn as_event(&self) -> &Event {
    &self.ui_event.event
  }
}
