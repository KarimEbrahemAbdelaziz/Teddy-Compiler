//
//  Parser.swift
//  Compiler
//
//  Created by Janum Trivedi on 2/16/17.
//  Copyright © 2017 Janum Trivedi. All rights reserved.
//

import Foundation

//
// Expression   ->   Constant | Identifier | (Expression)
//
//
//

public enum ParseError: Error {
    case expectedCharacter(String)
    case expectedIdentifier
    case expectedNumber
    case expectedStringLiteral
    case expectedExpression
    case expectedPrint
    case expectedOperator
    case expectedType
    case expectedReturn
    case expectedVariableDeclaration
    case expectedEnum
}


public class Parser {
    
    let tokens: [Token]
    var index = 0;
    
    init(tokens: [Token]) {
        self.tokens = tokens
    }
    
    func tokensAvailable() -> Bool {
        return index < tokens.count
    }
    
    func peekCurrentToken() -> Token {
        return tokens[index]
    }
    
    func popCurrentToken() -> Token {
        let token = tokens[index]
        index += 1
        return token
    }
    
    func getCurrentTokenPrecedence() throws -> Int {
        guard tokensAvailable() else { return -1 }
        
        let currentToken = peekCurrentToken()
        
        switch currentToken {
        case .T_Operator(_, let prec): return prec
        default: return -1
        }
    }
    
    func parse() throws -> [ExpressionType] {
        var nodes = [ExpressionType]()
        while tokensAvailable() {
            let statement = try parseStatement()
            nodes.append(statement)
        }
        
        return nodes
    }
    
    func parseStatement() throws -> ExpressionType {
        switch peekCurrentToken() {
        case .T_Function():
            return try parseFunctionDefinition()
            
        case .T_Enum():
            return try parseEnumDefinition()
            
        case .T_Let():
            return try parseVariableDeclaration()
            
        case .T_Return():
            return try parseReturn()
            
        case .T_Print():
            return try parsePrint()
            
        default:
            return try parseExpression()
        }
    }
    
    func parseExpression() throws -> ExpressionType {
        let node = try parsePrimaryExpression()
        return try parseBinaryOp(node: node)
    }
    
    func parsePrimaryExpression() throws -> ExpressionType {
        switch peekCurrentToken() {
        case .T_Identifier(_):
            return try parseIdentifierOrFunctionCall()
            
//        case .T_Period():
//            return try parseEnumCase();
            
        case .T_IntegerConstant(_):
            return try parseInteger()
            
        case .T_FloatConstant(_):
            return try parseFloat()
            
        case .T_StringConstant(_):
            return try parseString()
            
        case .T_ParensOpen():
            return try parseParens()
            
        default:
            throw ParseError.expectedExpression
        }
    }
    
    func parseEnumDefinition() throws -> EnumDefinitionNode {
//        enum Result {
//            case Success(result: Int)
//        }
        
        guard case Token.T_Enum() = popCurrentToken() else {
            throw ParseError.expectedEnum
        }
        
        guard case Token.T_Identifier(let enumName) = popCurrentToken() else {
            throw ParseError.expectedIdentifier
        }
        
        // Pop T_ParensOpen
        let _ = popCurrentToken()
        
        var cases = [EnumCaseDefinitionNode]()
        
        while true {
            if case Token.T_BraceClose() = peekCurrentToken() {
                let _ = popCurrentToken()
                break
            }
            
            if case Token.T_Case() = popCurrentToken() {
                
                guard case Token.T_Identifier(let caseName) = peekCurrentToken() else {
                    throw ParseError.expectedIdentifier
                }
                
                // Pop T_Identifier
                let _ = popCurrentToken()
                
                // Parse argument list
                let formals = try parsePrototypeArgumentList()
                
                // Pop T_Semicolon
                let _ = popCurrentToken()
                
                let caseNode = EnumCaseDefinitionNode(enumName: enumName, caseName: caseName, associatedValues: formals)
                cases.append(caseNode)
            }
            
        }
        
        return EnumDefinitionNode(name: enumName, cases: cases)
    }
    
    func parseReturn() throws -> ReturnNode {
        guard case Token.T_Return() = popCurrentToken() else {
            throw ParseError.expectedReturn
        }
        
        let expression = try parseExpression()
        
        // Pop T_Semicolon
        let _ = popCurrentToken()
        
        return ReturnNode(returnExpression: expression)
    }
    
    func parsePrint() throws -> PrintNode {
        guard case Token.T_Print() = popCurrentToken() else {
            throw ParseError.expectedPrint
        }
        
        let expressions = try parseExpressionCallList()
        
        // Pop T_Semicolon
        let _ = popCurrentToken()
        
        return PrintNode(printExpressions: expressions)
    }
    
    func parseEnumCase(enumType: TypeNode) throws -> EnumNode {
        // .Addition()
        // .Addition(x, y)
        
        guard case Token.T_Period() = popCurrentToken() else {
            throw ParseError.expectedCharacter(".")
        }
        
        let caseName = try readIdentifier()
        
        let arguments = try parseExpressionCallList()
        
        let rhsValue = EnumNode(enumName: enumType.name, caseName: caseName, arguments: arguments)
        
        return rhsValue
        
//        let enumCase = EnumCaseNode(enumName: "todo", caseName: caseName, associatedValues: arguments)
        
    }
    
    func parseVariableDeclaration() throws -> ExpressionType {
        // let i: Int;
        
        var mutability: Mutability! = nil
        if case Token.T_Let() = peekCurrentToken() {
            mutability = .immutable
        }
        else if case Token.T_Var() = peekCurrentToken() {
            mutability = .mutable
        }
        else {
            throw ParseError.expectedVariableDeclaration
        }
        
        let _ = popCurrentToken()
        
        guard case let Token.T_Identifier(identifier) = popCurrentToken() else {
            throw ParseError.expectedIdentifier
        }
        
        let _ = popCurrentToken()

        let type = try parseType()
        
        if case Token.T_Semicolon() = peekCurrentToken() {
            // Pop T_Semicolon
            let _ = popCurrentToken()
        }

        else if case Token.T_Equal() = peekCurrentToken() {
            // Pop T_Equal
            let _ = popCurrentToken()
            
            if case Token.T_Period() = peekCurrentToken() {
                // Assign expression is an enum
                // Special case
                
                let assignValue = try parseEnumCase(enumType: type)
                
                let variable = VariableNode(mutability: mutability, type: type, identifier: identifier)
                
                // Pop T_Semicolon
                let _ = popCurrentToken()
                
                return AssignExpression(variable: variable, value: assignValue)
                
            }
            else {
                // Standard assign expression
                
                let assignValue = try parseExpression()
                
                let variable = VariableNode(mutability: mutability, type: type, identifier: identifier)
                
                let _ = popCurrentToken()
                
                return AssignExpression(variable: variable, value: assignValue)
            }
            
//            let assignValue = try parseExpression()
//            
//            let variable = VariableNode(mutability: mutability, type: type, identifier: identifier)
//            
//            let _ = popCurrentToken()
//            
//            return AssignExpression(variable: variable, value: assignValue)
        }
        else {
            throw ParseError.expectedCharacter(";")
        }
        
        return VariableNode(mutability: mutability, type: type, identifier: identifier)
    }
    
    func parseType() throws -> TypeNode {
        // Int, Void, Bool, String, Float, etc.
        switch popCurrentToken() {
        case .T_Integer(): return TypeNode.integerType
        case .T_Float(): return TypeNode.floatType
        case .T_String(): return TypeNode.stringType
        case .T_Bool(): return TypeNode.boolType
        case .T_Void(): return TypeNode.voidType
        case .T_Identifier(let typeName): return TypeNode(name: typeName)
        default:
            throw ParseError.expectedType
        }
    }
    
    func parseFunctionDefinition() throws -> FunctionNode {
        
        // Pop T_Function
        guard case Token.T_Function() = popCurrentToken() else {
            throw ParseError.expectedCharacter("func")
        }
        
        let prototype = try parsePrototype()
        
        // Pop T_BraceOpen
        let _ = popCurrentToken()
        
        var body = [ExpressionType]()
        
        if case Token.T_BraceClose() = peekCurrentToken() {
            let _ = popCurrentToken()
            body = []
        }
        else {
            while true {
                if case Token.T_BraceClose() = peekCurrentToken() {
                    let _ = popCurrentToken()
                    break
                }
                
                let node = try parseStatement()
                body.append(try parseBinaryOp(node: node))
            }
        }
        
        return FunctionNode(prototype: prototype, body: body)
    }
    
    func parsePrototype() throws -> PrototypeNode {
        // factorial(n: Int)
        
        guard case let Token.T_Identifier(functionName) = popCurrentToken() else {
            throw ParseError.expectedIdentifier
        }
        
        // Parse function formals
        let arguments = try parsePrototypeArgumentList()
        
        // Pop T_Arrow
        let _ = popCurrentToken()
        
        // Expect a type keyword
        let returnType = try parseType()

        return PrototypeNode(name: functionName, arguments: arguments, returnType: returnType)
    }
    
    func parsePrototypeArgumentList() throws -> [VariableNode] {
        // (n: Int, x: String, y: Int)
        // (n: Int)
        
        // Pop T_ParensOpen
        let _ = popCurrentToken()
        
        var arguments = [VariableNode]()
        
        while true {
            if case Token.T_ParensClose() = peekCurrentToken() {
                break
            }
            else {
                if case Token.T_Identifier(let identifier) = popCurrentToken() {
                    let _ = popCurrentToken()
                    
                    let type = try parseType()
                    
                    let argument = VariableNode(mutability: .immutable, type: type, identifier: identifier)
                    
                    arguments.append(argument)
                }
            }
        }

        // Pop T_ParensOpen
        let _ = popCurrentToken()
        
        return arguments
    }
    
    func parseExpressionCallList() throws -> [ExpressionType] {
        
        // (x, 5, x + y)
        
        // Pop T_ParensOpen
        let _ = popCurrentToken()
        
        var arguments = [ExpressionType]()
        
        while true {
            if case Token.T_ParensClose() = peekCurrentToken() {
                break
            }
            if case Token.T_Comma() = peekCurrentToken() {
                let _ = popCurrentToken()
            }
            else {
                let argument = try parseExpression()
                arguments.append(argument)
            }
        }
        
        // Pop T_ParensOpen
        let _ = popCurrentToken()
        
        return arguments
    }
    
    func parseIdentifierOrFunctionCall() throws -> ExpressionType {
        
        // TODO: ArithmeticExpression.Addition
        
        let name = try readIdentifier()
        
        // TODO: This ignores a semicolon
//        guard tokensAvailable() else {
//            return FieldAccessNode(identifier: name)
//        }
        
        
//        if case Token.T_Period() = peekCurrentToken() {
//            // Arithmetic.Addition()
//            // enum case
//            
//            let enumTypeName = name
//            
//            // Pop T_Period
////            let _ = popCurrentToken()
//            
//            let enumCaseName = try parseEnumCase()
//        }
//        
        
        guard case Token.T_ParensOpen() = peekCurrentToken() else {
            return FieldAccessNode(identifier: name)
        }
        
        
        
        let arguments = try parseExpressionCallList()
        

        // TODO: This shouldn't be handled here. Calls are expressions, not statements.
        if case Token.T_Semicolon() = peekCurrentToken() {
            let _ = popCurrentToken()
        }
        
        return CallNode(identifier: name, arguments: arguments)
    }
    
    
    // MARK: - Expression (primary)
    
    func parseBinaryOp(node: ExpressionType, exprPrecedence: Int = 0) throws -> ExpressionType {
        
        var lhs = node
        
        while true {
            
            let tokenPrecedence = try getCurrentTokenPrecedence()

            if tokenPrecedence < exprPrecedence {
                return lhs
            }
            
            guard case let Token.T_Operator(op, _) = popCurrentToken() else {
                throw ParseError.expectedOperator
            }
            
            var rhs = try parseExpression()
            
            let nextPrecedence = try getCurrentTokenPrecedence()
            
            if tokenPrecedence < nextPrecedence {
                rhs = try parseBinaryOp(node: rhs, exprPrecedence: tokenPrecedence + 1)
            }
            
            lhs = BinaryOperationNode(lhs: lhs, operation: op, rhs: rhs)
        }
        
    }
    
    func parseParens() throws -> ExpressionType {
        // (E) -> E
        // (5) -> 5
        
        guard case Token.T_ParensOpen() = popCurrentToken() else {
            throw ParseError.expectedCharacter("(")
        }
        
        let expression = try parseExpression()
        
        guard case Token.T_ParensClose() = popCurrentToken() else {
            throw ParseError.expectedCharacter(")")
        }
        
        return expression
    }
    
    func parseInteger() throws -> ExpressionType {
        guard case Token.T_IntegerConstant(let value) = popCurrentToken() else {
            throw ParseError.expectedNumber
        }
        return IntegerNode(value: value)
    }
    
    func parseFloat() throws -> ExpressionType {
        guard case Token.T_FloatConstant(let value) = popCurrentToken() else {
            throw ParseError.expectedNumber
        }
        return FloatNode(value: value)
    }
    
    func parseString() throws -> ExpressionType {
        guard case Token.T_StringConstant(let value) = popCurrentToken() else {
            throw ParseError.expectedStringLiteral
        }
        return StringNode(value: value)
    }
    
    func readIdentifier() throws -> String {
        guard case let Token.T_Identifier(identifier) = popCurrentToken() else {
            throw ParseError.expectedIdentifier
        }
        return identifier
    }
    
}



