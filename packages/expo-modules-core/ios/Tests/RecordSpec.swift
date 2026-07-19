import Testing

@testable import ExpoModulesCore

@Suite("Record")
struct RecordTests {
  let appContext = AppContext.create()

  @Test
  func `initializes with empty dictionary`() throws {
    struct TestRecord: Record { }
    _ = try TestRecord(from: [:], appContext: appContext)
  }

  @Test
  func `works back and forth with a field`() throws {
    struct TestRecord: Record {
      @Field var a: String?
    }
    let dict = ["a": "b"]
    let record = try TestRecord(from: dict, appContext: appContext)

    #expect(record.a == dict["a"])
    #expect(record.toDictionary()["a"] as? String == dict["a"]!)
  }

  @Test
  func `works back and forth with an enum`() throws {
    enum StringEnum: String, Enumerable {
      case deleted
      case created
    }
    enum IntEnum: Int, Enumerable {
      case one = 1
      case two
    }
    struct TestRecord: Record {
      @Field var a: StringEnum = .created
      @Field var b: IntEnum?
    }
    let dict = ["a": "deleted", "b": 1]
    let record = try TestRecord(from: dict, appContext: appContext)

    #expect(record.a == StringEnum.deleted)
    #expect(record.b == IntEnum.one)

    #expect(record.toDictionary()["a"] as? String == dict["a"]! as? String)
    #expect(record.toDictionary()["b"] as? Int == dict["b"]! as? Int)
  }

  @Test
  func `works back and forth with ValueOrUndefined`() throws {
    struct TestRecord: Record {
      @Field var a: ValueOrUndefined<Double> = .value(unwrapped: 1.0)
      @Field var b: ValueOrUndefined<Double> = .undefined
    }
    let record = try TestRecord(from: [:], appContext: appContext)

    #expect(record.a.optional == 1.0)
    #expect(record.b.isUndefined == true)

    let asDict = record.toDictionary(appContext: appContext)
    #expect(asDict["a"] as? Double == 1.0)
    #expect((asDict["b"] as? JavaScriptValue)?.kind == .undefined)
  }

  @Test
  func `works back and forth with Either`() throws {
    struct TestRecord: Record {
      @Field var stringValue: Either<Bool, String>?
      @Field var boolValue: Either<Bool, String>?
      @Field var intValue: Either<Int, String>?
      @Field var nilValue: Either<Int, String>?
    }
    let dict: [String: Any] = [
      "stringValue": "custom",
      "boolValue": true,
      "intValue": 42,
    ]
    let record = try TestRecord(from: dict, appContext: appContext)
    #expect(record.stringValue?.get() as String? == "custom")
    #expect(record.boolValue?.get() as Bool? == true)
    #expect(record.intValue?.get() as Int? == 42)
    #expect(record.nilValue == nil)

    let asDict = record.toDictionary(appContext: appContext)
    #expect(asDict["stringValue"] as? String == "custom")
    #expect(asDict["boolValue"] as? Bool == true)
    #expect(asDict["intValue"] as? Int == 42)
    #expect(asDict["nilValue"] as? Int == nil)
  }

  @Test
  func `works back and forth with a keyed field`() throws {
    struct TestRecord: Record {
      @Field("key") var a: String?
    }
    let dict = ["key": "b"]
    let record = try TestRecord(from: dict, appContext: appContext)

    #expect(record.a == dict["key"])
    #expect(record.toDictionary()["key"] as? String == dict["key"]!)
  }

  @Test
  func `throws when required field is missing`() throws {
    struct TestRecord: Record {
      @Field(.required) var a: Int
    }

    #expect(throws: FieldRequiredException.self) {
      try TestRecord(from: [:], appContext: appContext)
    }
  }

  @Test
  func `throws when casting is not possible`() throws {
    struct TestRecord: Record {
      @Field var a: Int
    }
    let dict = ["a": "try with String instead of Int"]

    #expect(throws: FieldInvalidTypeException.self) {
      try TestRecord(from: dict, appContext: appContext)
    }
  }

  @Test
  func `serializes concurrently on a shared record without crashing`() {
    struct StressRecord: Record {
      @Field var a: String? = nil
      @Field var b: String? = nil
      @Field var c: String? = nil
    }

    let record = StressRecord(a: "a", b: "b", c: "c")
    let workers = 16
    let iterations = 100
    let group = DispatchGroup()
    let startGate = DispatchSemaphore(value: 0)

    for _ in 0..<workers {
      group.enter()
      DispatchQueue.global(qos: .userInitiated).async {
        startGate.wait()
        for _ in 0..<iterations {
          _ = record.toDictionary()
        }
        group.leave()
      }
    }
    // Release every worker so they collide on the first reflection.
    for _ in 0..<workers { startGate.signal() }
    group.wait()

    let finalDict = record.toDictionary()
    #expect(finalDict.keys.count == 3)
    #expect(finalDict["a"] as? String == "a")
    #expect(finalDict["c"] as? String == "c")
  }
}
