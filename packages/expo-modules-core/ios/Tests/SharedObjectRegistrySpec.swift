// Copyright 2022-present 650 Industries. All rights reserved.

import Foundation
import Testing

@testable import ExpoModulesCore

@Suite("SharedObjectRegistry")
struct SharedObjectRegistryTests {
  @Suite("pullNextId", .serialized)
  @JavaScriptActor
  struct PullNextIdTests {
    let appContext: AppContext
    let runtime: ExpoRuntime
    let sharedObjectRegistry: SharedObjectRegistry

    init() throws {
      appContext = AppContext.create()
      runtime = try appContext.runtime
      sharedObjectRegistry = appContext.sharedObjectRegistry
    }

    @Test
    func `returns nextId`() {
      let id = sharedObjectRegistry.nextId
      #expect(sharedObjectRegistry.pullNextId() == id)
    }

    @Test
    func `increments nextId`() {
      let id = sharedObjectRegistry.nextId
      sharedObjectRegistry.pullNextId()
      #expect(sharedObjectRegistry.nextId == id + 1)
    }

    @Test
    func `is not increasing size`() {
      let size = sharedObjectRegistry.size
      sharedObjectRegistry.pullNextId()
      #expect(sharedObjectRegistry.size == size)
    }
  }

  @Suite("add", .serialized)
  @JavaScriptActor
  struct AddTests {
    let appContext: AppContext
    let runtime: ExpoRuntime
    let sharedObjectRegistry: SharedObjectRegistry

    init() throws {
      appContext = AppContext.create()
      runtime = try appContext.runtime
      sharedObjectRegistry = appContext.sharedObjectRegistry
    }

    @Test
    func `adds using nextId`() {
      let nextId = sharedObjectRegistry.nextId
      let id = sharedObjectRegistry.add(native: TestSharedObject(), javaScript: runtime.createObject())
      #expect(nextId == id)
    }

    @Test
    func `is increasing size`() {
      let size = sharedObjectRegistry.size
      sharedObjectRegistry.add(native: TestSharedObject(), javaScript: runtime.createObject())
      #expect(sharedObjectRegistry.size == size + 1)
    }

    @Test
    func `assigns id on native object`() {
      let nativeObject = TestSharedObject()
      let id = sharedObjectRegistry.add(native: nativeObject, javaScript: runtime.createObject())
      #expect(nativeObject.sharedObjectId == id)
    }

    @Test
    func `assigns the app context on native object`() {
      let nativeObject = TestSharedObject()
      sharedObjectRegistry.add(native: nativeObject, javaScript: runtime.createObject())
      #expect(nativeObject.appContext == appContext)
    }

    @Test
    func `assigns id on JS object`() {
      let jsObject = runtime.createObject()
      let id = sharedObjectRegistry.add(native: TestSharedObject(), javaScript: jsObject)
      #expect(jsObject.hasProperty(sharedObjectIdPropertyName) == true)
      #expect(try! jsObject.getProperty(sharedObjectIdPropertyName).asInt() == id)
    }

    @Test
    func `saves objects pair`() {
      let nativeObject = TestSharedObject()
      let jsObject = runtime.createObject()
      let id = sharedObjectRegistry.add(native: nativeObject, javaScript: jsObject)
      let nativeState = sharedObjectRegistry.get(id)
      #expect(nativeState?.native === nativeObject)
      #expect(nativeState?.javaScriptObject(in: runtime)?.asValue() == jsObject.asValue())
    }
  }

  @Suite("delete", .serialized)
  @JavaScriptActor
  struct DeleteTests {
    let appContext: AppContext
    let runtime: ExpoRuntime
    let sharedObjectRegistry: SharedObjectRegistry

    init() throws {
      appContext = AppContext.create()
      runtime = try appContext.runtime
      sharedObjectRegistry = appContext.sharedObjectRegistry
    }

    @Test
    func `deletes objects pair`() {
      let id = sharedObjectRegistry.add(native: TestSharedObject(), javaScript: runtime.createObject())
      sharedObjectRegistry.delete(id)
      #expect(sharedObjectRegistry.get(id) == nil)
    }

    @Test
    func `resets id on native object`() async {
      let nativeObject = TestSharedObject()
      let id = sharedObjectRegistry.add(native: nativeObject, javaScript: runtime.createObject())
      sharedObjectRegistry.delete(id)
      await eventually { nativeObject.sharedObjectId == 0 }
      #expect(nativeObject.sharedObjectId == 0)
    }
  }

  @Suite("toNativeObject", .serialized)
  @JavaScriptActor
  struct ToNativeObjectTests {
    let appContext: AppContext
    let runtime: ExpoRuntime
    let sharedObjectRegistry: SharedObjectRegistry

    init() throws {
      appContext = AppContext.create()
      runtime = try appContext.runtime
      sharedObjectRegistry = appContext.sharedObjectRegistry
    }

    @Test
    func `returns native object`() {
      let nativeObject = TestSharedObject()
      let jsObject = runtime.createObject()
      sharedObjectRegistry.add(native: nativeObject, javaScript: jsObject)
      #expect(sharedObjectRegistry.toNativeObject(jsObject) === nativeObject)
    }

    @Test
    func `returns nil`() {
      let jsObject = runtime.createObject()
      #expect(sharedObjectRegistry.toNativeObject(jsObject) == nil)
    }
  }

  @Suite("toJavaScriptObject", .serialized)
  @JavaScriptActor
  struct ToJavaScriptObjectTests {
    let appContext: AppContext
    let runtime: ExpoRuntime
    let sharedObjectRegistry: SharedObjectRegistry

    init() throws {
      appContext = AppContext.create()
      runtime = try appContext.runtime
      sharedObjectRegistry = appContext.sharedObjectRegistry
    }

    @Test
    func `returns JS object`() {
      let nativeObject = TestSharedObject()
      let jsObject = runtime.createObject()
      sharedObjectRegistry.add(native: nativeObject, javaScript: jsObject)
//        #expect(sharedObjectRegistry.toJavaScriptObject(nativeObject) == jsObject)
    }

    @Test
    func `returns nil`() {
      let nativeObject = TestSharedObject()
//        #expect(sharedObjectRegistry.toJavaScriptObject(nativeObject) == nil)
    }
  }
}

fileprivate func eventually(timeout: TimeInterval = 1.0, _ condition: () -> Bool) async {
  let deadline = Date().addingTimeInterval(timeout)
  while !condition() && Date() < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
  }
}

fileprivate final class TestSharedObject: SharedObject {}
