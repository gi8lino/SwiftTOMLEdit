import SwiftTOMLEdit
import XCTest

final class TOMLDocumentTests: XCTestCase {
  func testParseProvidesTypedValues() throws {
    let table = try TOMLTable(
      string: """
        title = "SwiftTOMLEdit"
        enabled = true
        count = 3
        ratio = 1.5
        released_at = 2026-07-25T12:30:00Z
        fields = ["time", "date"]

        [nested]
        value = "kept"
        """
    )

    XCTAssertEqual(table["title"]?.string, "SwiftTOMLEdit")
    XCTAssertEqual(table["enabled"]?.bool, true)
    XCTAssertEqual(table["count"]?.int, 3)
    XCTAssertEqual(table["ratio"]?.double, 1.5)
    XCTAssertEqual(table["released_at"]?.datetime, "2026-07-25T12:30:00Z")
    XCTAssertEqual(table["fields"]?.array?.compactMap(\.string), ["time", "date"])
    XCTAssertEqual(table["nested"]?.table?["value"]?.string, "kept")
  }

  func testDocumentParseMatchesTableInitializer() throws {
    let source = "name = \"value\"\n"

    XCTAssertEqual(
      try TOMLDocument.parse(source),
      try TOMLTable(string: source)
    )
  }

  func testEditPreservesCommentsWhitespaceAndUnchangedOrdering() throws {
    let source = """
      # User heading
      [calendar]
      popup_mode   = "month" # Keep inline explanation

      # Keep this block attached to the next setting
      enabled = true
      """

    let edited = try TOMLDocument.edit(
      source,
      edits: [
        TOMLEdit(
          path: ["calendar", "popup_mode"],
          value: .string("upcoming")
        )
      ]
    )

    XCTAssertEqual(
      edited,
      source.replacingOccurrences(of: "\"month\"", with: "\"upcoming\"")
    )
  }

  func testEditAddsMissingNestedTablesAndArray() throws {
    let edited = try TOMLDocument.edit(
      "# Existing comment\n",
      edits: [
        TOMLEdit(
          path: ["calendar", "anchor", "fields"],
          value: .stringArray(["date", "time"])
        )
      ]
    )
    let table = try TOMLTable(string: edited)

    XCTAssertTrue(edited.contains("# Existing comment"))
    XCTAssertEqual(
      table["calendar"]?.table?["anchor"]?.table?["fields"]?.array?.compactMap(\.string),
      ["date", "time"]
    )
  }

  func testEditPreservesInlineTablesAndComments() throws {
    let source = "settings = { ui = { enabled = true, count = 10 } } # Keep me\n"

    let edited = try TOMLDocument.edit(
      source,
      edits: [
        TOMLEdit(
          path: ["settings", "ui", "enabled"],
          value: .bool(false)
        )
      ]
    )

    XCTAssertEqual(
      edited,
      source.replacingOccurrences(of: "enabled = true", with: "enabled = false")
    )
  }

  func testEditPreservesMissingTrailingNewline() throws {
    let source = "enabled = true"

    let edited = try TOMLDocument.edit(
      source,
      edits: [TOMLEdit(path: ["enabled"], value: .bool(false))]
    )

    XCTAssertEqual(edited, "enabled = false")
    XCTAssertFalse(edited.hasSuffix("\n"))
  }

  func testParseErrorContainsUnicodeAwareSourceLocation() {
    let source = "title = \"Grüezi\"\n[broken\nvalue = true"

    XCTAssertThrowsError(try TOMLTable(string: source)) { error in
      guard let parseError = error as? TOMLParseError else {
        return XCTFail("Unexpected error: \(error)")
      }

      XCTAssertEqual(parseError.line, 2)
      XCTAssertNotNil(parseError.column)
      XCTAssertFalse(parseError.message.isEmpty)
      XCTAssertNotNil(parseError.start)
    }
  }
}
