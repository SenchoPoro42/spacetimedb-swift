//
//  CodegenTests.swift
//  SpacetimeDBCodegenTests
//
//  Tests for the SpacetimeDB code generator.
//

import XCTest
@testable import SpacetimeDBCodegenLib

final class CodegenTests: XCTestCase {
    
    // MARK: - Schema Parsing Tests
    
    func testParseSimpleSchema() throws {
        let json = """
        {
            "typespace": {
                "types": [
                    {
                        "Product": {
                            "elements": [
                                {
                                    "name": {"some": "name"},
                                    "algebraic_type": {"Builtin": {"String": []}}
                                }
                            ]
                        }
                    }
                ]
            },
            "tables": [
                {
                    "name": "person",
                    "product_type_ref": 0,
                    "primary_key": [],
                    "indexes": [],
                    "constraints": [],
                    "sequences": [],
                    "schedule": {"none": []},
                    "table_type": {"User": []},
                    "table_access": {"Public": []}
                }
            ],
            "reducers": [
                {
                    "name": "add",
                    "params": {
                        "elements": [
                            {
                                "name": {"some": "name"},
                                "algebraic_type": {"Builtin": {"String": []}}
                            }
                        ]
                    },
                    "lifecycle": {"none": []}
                }
            ]
        }
        """
        
        let schema = try SchemaLoader.loadFromString(json)
        
        XCTAssertEqual(schema.tables.count, 1)
        XCTAssertEqual(schema.tables[0].name, "person")
        XCTAssertEqual(schema.reducers.count, 1)
        XCTAssertEqual(schema.reducers[0].name, "add")
        XCTAssertTrue(schema.reducers[0].isCallable)
    }
    
    func testParseLifecycleReducer() throws {
        let json = """
        {
            "typespace": {"types": []},
            "tables": [],
            "reducers": [
                {
                    "name": "init",
                    "params": {"elements": []},
                    "lifecycle": {"some": {"OnInit": []}}
                }
            ]
        }
        """
        
        let schema = try SchemaLoader.loadFromString(json)
        
        XCTAssertEqual(schema.reducers.count, 1)
        XCTAssertFalse(schema.reducers[0].isCallable)
        XCTAssertEqual(schema.reducers[0].lifecycle, .onInit)
    }
    
    // MARK: - Naming Convention Tests
    
    func testSnakeToCamelCase() {
        XCTAssertEqual("send_message".snakeToCamelCase(), "sendMessage")
        XCTAssertEqual("user_id".snakeToCamelCase(), "userId")
        XCTAssertEqual("simple".snakeToCamelCase(), "simple")
        XCTAssertEqual("a_b_c".snakeToCamelCase(), "aBC")
    }
    
    func testSnakeToPascalCase() {
        XCTAssertEqual("send_message".snakeToPascalCase(), "SendMessage")
        XCTAssertEqual("user".snakeToPascalCase(), "User")
        XCTAssertEqual("my_table_name".snakeToPascalCase(), "MyTableName")
    }
    
    func testSwiftKeywordEscaping() {
        XCTAssertEqual("class".asSwiftIdentifier(), "`class`")
        XCTAssertEqual("func".asSwiftIdentifier(), "`func`")
        XCTAssertEqual("normalName".asSwiftIdentifier(), "normalName")
    }
    
    // MARK: - Type Mapping Tests
    
    func testBuiltinTypeMapping() {
        let typespace = Typespace(types: [])
        let mapper = TypeMapper(typespace: typespace)
        
        XCTAssertEqual(mapper.mapBuiltin(.bool), "Bool")
        XCTAssertEqual(mapper.mapBuiltin(.i32), "Int32")
        XCTAssertEqual(mapper.mapBuiltin(.u64), "UInt64")
        XCTAssertEqual(mapper.mapBuiltin(.f64), "Double")
        XCTAssertEqual(mapper.mapBuiltin(.string), "String")
    }
    
    func testArrayTypeMapping() {
        let typespace = Typespace(types: [])
        let mapper = TypeMapper(typespace: typespace)
        
        let arrayType = BuiltinType.array(.builtin(.string))
        XCTAssertEqual(mapper.mapBuiltin(arrayType), "[String]")
    }
    
    // MARK: - Code Builder Tests
    
    func testCodeBuilderBasics() {
        let builder = SwiftCodeBuilder()
        builder.line("import Foundation")
        builder.line()
        builder.line("struct Foo {")
        builder.indent()
        builder.line("let x: Int")
        builder.outdent()
        builder.line("}")
        
        let code = builder.build()
        XCTAssertTrue(code.contains("import Foundation"))
        XCTAssertTrue(code.contains("struct Foo {"))
        XCTAssertTrue(code.contains("    let x: Int"))
        XCTAssertTrue(code.contains("}"))
    }
    
    func testCodeBuilderBlock() {
        let builder = SwiftCodeBuilder()
        builder.block("struct Foo") { b in
            b.line("let x: Int")
        }
        
        let code = builder.build()
        XCTAssertTrue(code.contains("struct Foo {"))
        XCTAssertTrue(code.contains("    let x: Int"))
        XCTAssertTrue(code.contains("}"))
    }
    
    // MARK: - Generator Integration Tests
    
    func testModuleGeneratorOutput() throws {
        let json = """
        {
            "typespace": {
                "types": [
                    {
                        "Product": {
                            "elements": [
                                {
                                    "name": {"some": "id"},
                                    "algebraic_type": {"Builtin": {"U64": []}}
                                },
                                {
                                    "name": {"some": "name"},
                                    "algebraic_type": {"Builtin": {"String": []}}
                                }
                            ]
                        }
                    }
                ]
            },
            "tables": [
                {
                    "name": "user",
                    "product_type_ref": 0,
                    "primary_key": [0],
                    "indexes": [],
                    "constraints": [],
                    "sequences": [],
                    "schedule": {"none": []},
                    "table_type": {"User": []},
                    "table_access": {"Public": []}
                }
            ],
            "reducers": [
                {
                    "name": "create_user",
                    "params": {
                        "elements": [
                            {
                                "name": {"some": "name"},
                                "algebraic_type": {"Builtin": {"String": []}}
                            }
                        ]
                    },
                    "lifecycle": {"none": []}
                }
            ]
        }
        """
        
        let schema = try SchemaLoader.loadFromString(json)
        let generator = ModuleGenerator(moduleDef: schema)
        let files = generator.generateAll()
        
        // Should generate type, table wrapper, reducer, and integration files
        XCTAssertTrue(files.count >= 5)
        
        // Check for expected files
        let filenames = files.map { $0.filename }
        XCTAssertTrue(filenames.contains("User.swift"))
        XCTAssertTrue(filenames.contains("UserTable.swift"))
        XCTAssertTrue(filenames.contains("CreateUserReducer.swift"))
        XCTAssertTrue(filenames.contains("RemoteTables.swift"))
        XCTAssertTrue(filenames.contains("RemoteReducers.swift"))
    }
}
