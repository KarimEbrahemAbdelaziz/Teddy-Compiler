//
//  main.swift
//  Compiler
//
//  Created by Janum Trivedi on 2/16/17.
//  Copyright © 2017 Janum Trivedi. All rights reserved.
//

// Replace this with your own absolute path to main.teddy (included in this project).
let teddyAbsolutePath = "/Users/janum/Teddy/Compiler/main.teddy"

if let rawSource = Loader.read(file: teddyAbsolutePath) {

    let source = Preprocessor.stripComments(from: rawSource)
    
    String.printHeader(text: "Source Input (.teddy)")
    print(source)
    

    String.printHeader(text: "Lexical Analysis")
    let tokens = Lexer.tokenize(input: source)
    tokens.forEach { print($0) }

    
    String.printHeader(text: "Parsing & Semantic Analysis")
    
    let parser = Parser(tokens: tokens)
    let ast = try parser.parse()
    dump(ast)

    
    String.printHeader(text: "Code Generation (Target: C)")
    
    let generator = CodeGenerator(abstractSyntaxTree: ast)
    try generator.emit(to: .c)
    
    print()
}
