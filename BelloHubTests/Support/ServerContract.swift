//
//  ServerContract.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The server contract as the backend publishes it (`firebase/functions/contracts/schemas.json`, generated from the zod
/// schemas the functions validate with), so a request the app builds is checked against the real thing and not against
/// the app's own idea of it. The test bundle carries a byte-for-byte copy (a simulator process may not read the Mac's
/// Desktop); `scripts/check-server-contract.sh` fails when the copy drifts from the backend's file and
/// `scripts/sync-server-contract.sh` refreshes it.
enum ServerContract {
    private final class BundleToken {}

    enum Failure: Error {
        case missingFile
        case unknownFunction(String)
    }

    private typealias Schema = [String: Any]

    private static func schemas() throws -> [String: Any] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "schemas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw Failure.missingFile }
        return object
    }

    /// Every way `body` (the JSON the app sends) breaks the input schema of `function`; empty when it is valid.
    static func violations(of body: Data, for function: String) throws -> [String] {
        guard let entry = try schemas()[function] as? Schema, let schema = entry["input"] as? Schema
        else { throw Failure.unknownFunction(function) }
        return check(try JSONSerialization.jsonObject(with: body), against: schema, path: "$")
    }

    /// The names of every function the contract lists.
    static func functionNames() throws -> Set<String> {
        Set(try schemas().keys)
    }

    // MARK: - A small JSON Schema checker (only the keywords the generated schemas use)

    private static func check(_ value: Any, against schema: Schema, path: String) -> [String] {
        if let options = schema["anyOf"] as? [Schema] {
            let matches = options.contains { check(value, against: $0, path: path).isEmpty }
            return matches ? [] : ["\(path): matches none of anyOf"]
        }
        var problems: [String] = []
        if let constant = schema["const"], !equal(value, constant) { problems.append("\(path): not \(constant)") }
        if let allowed = schema["enum"] as? [Any], !allowed.contains(where: { equal(value, $0) }) {
            problems.append("\(path): \(value) not in enum")
        }
        switch schema["type"] as? String {
        case "object": problems += checkObject(value, schema, path)
        case "array": problems += checkArray(value, schema, path)
        case "string": problems += checkString(value, schema, path)
        case "integer": problems += checkNumber(value, schema, path, integer: true)
        case "number": problems += checkNumber(value, schema, path, integer: false)
        case "boolean" where !isBoolean(value): problems.append("\(path): not a boolean")
        default: break
        }
        return problems
    }

    private static func checkObject(_ value: Any, _ schema: Schema, _ path: String) -> [String] {
        guard let object = value as? [String: Any] else { return ["\(path): not an object"] }
        let required = schema["required"] as? [String] ?? []
        var problems = required.filter { object[$0] == nil }.map { "\(path).\($0): missing" }
        let properties = schema["properties"] as? [String: Schema] ?? [:]
        if let names = schema["propertyNames"] as? Schema {
            for key in object.keys { problems += check(key, against: names, path: "\(path){\(key)}") }
        }
        for (key, child) in object {
            if let childSchema = properties[key] {
                problems += check(child, against: childSchema, path: "\(path).\(key)")
            } else if let extra = schema["additionalProperties"] as? Schema, !extra.isEmpty {
                problems += check(child, against: extra, path: "\(path).\(key)")
            } else if schema["additionalProperties"] as? Bool == false {
                problems.append("\(path).\(key): not in the contract")
            }
        }
        return problems
    }

    private static func checkArray(_ value: Any, _ schema: Schema, _ path: String) -> [String] {
        guard let array = value as? [Any] else { return ["\(path): not an array"] }
        var problems: [String] = []
        if let minimum = schema["minItems"] as? Int, array.count < minimum { problems.append("\(path): too few") }
        if let maximum = schema["maxItems"] as? Int, array.count > maximum { problems.append("\(path): too many") }
        if let item = schema["items"] as? Schema {
            for (index, element) in array.enumerated() {
                problems += check(element, against: item, path: "\(path)[\(index)]")
            }
        }
        return problems
    }

    private static func checkString(_ value: Any, _ schema: Schema, _ path: String) -> [String] {
        guard let text = value as? String else { return ["\(path): not a string"] }
        var problems: [String] = []
        if let maximum = schema["maxLength"] as? Int, text.count > maximum { problems.append("\(path): too long") }
        if let minimum = schema["minLength"] as? Int, text.count < minimum { problems.append("\(path): too short") }
        if let pattern = schema["pattern"] as? String, text.range(of: pattern, options: .regularExpression) == nil {
            problems.append("\(path): \(text) does not match \(pattern)")
        }
        if schema["format"] as? String == "date-time", CallableJSON.parse(text) == nil {
            problems.append("\(path): not a date-time")
        }
        return problems
    }

    private static func checkNumber(_ value: Any, _ schema: Schema, _ path: String, integer: Bool) -> [String] {
        guard let number = value as? NSNumber, !isBoolean(value) else { return ["\(path): not a number"] }
        var problems: [String] = []
        let double = number.doubleValue
        if integer && double != double.rounded() { problems.append("\(path): not an integer") }
        if let minimum = (schema["minimum"] as? NSNumber)?.doubleValue, double < minimum {
            problems.append("\(path): below \(minimum)")
        }
        if let maximum = (schema["maximum"] as? NSNumber)?.doubleValue, double > maximum {
            problems.append("\(path): above \(maximum)")
        }
        return problems
    }

    /// JSON `true`/`false` as the parser returns them; `0` and `1` are numbers even though Swift bridges them to Bool.
    private static func isBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func equal(_ left: Any, _ right: Any) -> Bool {
        if let left = left as? String, let right = right as? String { return left == right }
        if let left = left as? NSNumber, let right = right as? NSNumber { return left.doubleValue == right.doubleValue }
        return false
    }
}
