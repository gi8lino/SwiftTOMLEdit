import SwiftTOMLEdit
import XCTest

private enum TestConfigError: Error, Equatable {
  case invalidType(path: String, expected: String, actual: String)
  case invalidValue(path: String, message: String)
}

private enum DisplayMode: String, CaseIterable, TOMLStringDecodable {
  case compact
  case expanded
}

final class TOMLConfigReaderTests: XCTestCase {
  func testReaderResolvesNestedValuesAndFallbacks() throws {
    let table = try TOMLTable(
      string: """
        [app]
        enabled = true
        count = 4
        ratio = 1.5
        mode = "expanded"
        fields = ["date", "time"]
        """
    )
    let reader = makeReader(table)
    let app = try reader.section("app")

    XCTAssertTrue(try app.bool("enabled", fallback: false))
    XCTAssertEqual(try app.int("count", fallback: 0, minimum: 1, maximum: 10), 4)
    XCTAssertEqual(try app.double("ratio", fallback: 0), 1.5)
    XCTAssertEqual(try app.enum("mode", fallback: DisplayMode.compact), .expanded)
    XCTAssertEqual(try app.stringArray("fields", fallback: []), ["date", "time"])
    XCTAssertEqual(try app.string("missing", fallback: "fallback"), "fallback")
  }

  func testReaderReportsInvalidTypeWithFullPath() throws {
    let table = try TOMLTable(string: "[app]\ncount = \"four\"\n")
    let app = try makeReader(table).section("app")

    XCTAssertThrowsError(try app.int("count", fallback: 0)) { error in
      XCTAssertEqual(
        error as? TestConfigError,
        .invalidType(path: "app.count", expected: "integer", actual: "string(four)")
      )
    }
  }

  func testReaderValidatesBounds() throws {
    let table = try TOMLTable(string: "[app]\ncount = 11\n")
    let app = try makeReader(table).section("app")

    XCTAssertThrowsError(try app.int("count", fallback: 0, minimum: 1, maximum: 10)) { error in
      XCTAssertEqual(
        error as? TestConfigError,
        .invalidValue(path: "app.count", message: "expected a value from 1 to 10")
      )
    }
  }

  private func makeReader(_ table: TOMLTable) -> TOMLConfigReader<TestConfigError> {
    TOMLConfigReader(
      table: table,
      path: "",
      makeInvalidTypeError: { path, expected, actual in
        .invalidType(path: path, expected: expected, actual: actual)
      },
      makeInvalidValueError: { path, message in
        .invalidValue(path: path, message: message)
      }
    )
  }
}
