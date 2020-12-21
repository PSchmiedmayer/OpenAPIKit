//
//  URLTemplateTests.swift
//  
//
//  Created by Mathew Polzin on 8/13/20.
//

import Foundation
import OpenAPIKit
import XCTest

final class URLTemplateTests: XCTestCase {
    func test_init() {
        XCTAssertNotNil(URLTemplate(rawValue: "https://website.com"))
        XCTAssertEqual(URLTemplate(rawValue: "https://website.com"), URLTemplate(url: URL(string: "https://website.com")!))
        XCTAssertNotNil(URLTemplate(rawValue: "{scheme}://website.com"))
    }

    func test_urlAccess() {
        let t1 = URLTemplate(rawValue: "https://website.com")
        let t2 = URLTemplate(rawValue: "{scheme}://website.com")

        XCTAssertEqual(t1?.url, URL(string: "https://website.com"))
        XCTAssertNil(t2?.url)
    }

    func test_absoluteString() {
        let t1 = URLTemplate(rawValue: "https://website.com")
        let t2 = URLTemplate(rawValue: "/a/relative/path")
        let t3 = URLTemplate(rawValue: "website.com?query=value")

        let t4 = URLTemplate(rawValue: "{scheme}://website.com/{path}")

        XCTAssertEqual(t1?.absoluteString, URL(string: "https://website.com")?.absoluteString)
        XCTAssertEqual(t2?.absoluteString, URL(string: "/a/relative/path")?.absoluteString)
        XCTAssertEqual(t3?.absoluteString, URL(string: "website.com?query=value")?.absoluteString)

        XCTAssertEqual(t4?.absoluteString, "{scheme}://website.com/{path}")
    }

    func test_componentErrors() {
        // unclosed variable brace
        XCTAssertNil(URLTemplate(rawValue: "{scheme://website.com"))
        XCTAssertThrowsError(try URLTemplate(templateString: "{scheme://website.com")) { error in
            XCTAssertEqual(
                String(describing: error),
                "An opening brace with no closing brace was found. The portion of the URL following the opening brace was 'scheme://website.com'"
            )
        }

        // unopened variable brace
        XCTAssertNil(URLTemplate(rawValue: "scheme}://website.com"))
        XCTAssertThrowsError(try URLTemplate(templateString: "scheme}://website.com")) { error in
            XCTAssertEqual(
                String(describing: error),
                "A closing brace with no opening brace was found. The portion of the URL preceeding the closing brace was 'scheme'"
            )
        }

        // nested variable brace
        XCTAssertNil(URLTemplate(rawValue: "{scheme}://website.com/{path{var}}"))
        XCTAssertThrowsError(try URLTemplate(templateString: "{scheme}://website.com/{path{var}}")) { error in
            XCTAssertEqual(
                String(describing: error),
                "An opening brace within another variable was found. The portion of the URL following the first opening brace up until the second opening brace was 'path'"
            )
        }

        // nested variable brace (doubled-up)
        XCTAssertNil(URLTemplate(rawValue: "{{scheme}}://website.com/{path}"))
        XCTAssertThrowsError(try URLTemplate(templateString: "{{scheme}}://website.com/{path}")) { error in
            XCTAssertEqual(
                String(describing: error),
                "An opening brace within another variable was found. The portion of the URL following the first opening brace up until the second opening brace was ''"
            )
        }
    }

    func test_componentSuccesses() {
        XCTAssertEqual(
            URLTemplate(rawValue: "{scheme}://website.com")?.components,
            [.variable(name: "scheme"), .constant("://website.com")]
        )

        XCTAssertEqual(
            URLTemplate(rawValue: "{scheme}://website.com/{path}")?.components,
            [.variable(name: "scheme"), .constant("://website.com/"), .variable(name: "path")]
        )

        XCTAssertEqual(
            URLTemplate(rawValue: "https://website.com/{path}?search=hello&page=2")?.components,
            [.constant("https://website.com/"), .variable(name: "path"), .constant("?search=hello&page=2")]
        )

        XCTAssertEqual(
            URLTemplate(rawValue: "{scheme}://website.com/{path}?search={query}&page={page}")?.components,
            [
                .variable(name: "scheme"),
                .constant("://website.com/"),
                .variable(name: "path"),
                .constant("?search="),
                .variable(name: "query"),
                .constant("&page="),
                .variable(name: "page")
            ]
        )
    }
}

// MARK: - Codable
extension URLTemplateTests {
    func test_encode() throws {
        let t1 = TemplatedURLWrapper(
            url: URLTemplate(rawValue: "https://website.com")
        )

        assertJSONEquivalent(
            try orderUnstableTestStringFromEncoding(of: t1),
            """
            {
              "url" : "https:\\/\\/website.com"
            }
            """
        )
    }

    func test_decode() throws {
        let t1Data = """
        {
          "url": "https://website.com"
        }
        """.data(using: .utf8)!

        let t1 = try orderUnstableDecode(TemplatedURLWrapper.self, from: t1Data)

        XCTAssertEqual(
            t1.url,
            URLTemplate(rawValue: "https://website.com")
        )
    }

    func test_encode_withVariables() throws {
        let t1 = TemplatedURLWrapper(
            url: URLTemplate(rawValue: "{scheme}://{host}.com")
        )

        assertJSONEquivalent(
            try orderUnstableTestStringFromEncoding(of: t1),
            """
            {
              "url" : "{scheme}:\\/\\/{host}.com"
            }
            """
        )
    }

    func test_decode_withVariables() throws {
        let t1Data = """
        {
          "url": "{scheme}://{host}.com"
        }
        """.data(using: .utf8)!

        let t1 = try orderUnstableDecode(TemplatedURLWrapper.self, from: t1Data)

        XCTAssertEqual(
            t1.url,
            URLTemplate(rawValue: "{scheme}://{host}.com")
        )
    }
}

fileprivate struct TemplatedURLWrapper: Codable {
    let url: URLTemplate?
}
