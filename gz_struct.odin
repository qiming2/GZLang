package main

// Lexer

/*
 If want to add features:
 Lexer:
    add a new kind to GZ_TOKEN_KIND if necessary.
    add a new regex pattern to all_pattern_strings.
Parser:
    add a new binding power into bp_map if it is an expression and also change binding power of other exprs accordingly (determines to precedence).
    add a new expr/stmt/decl type accordingly.
    modify parser functionality in parse_stmt, parse_expr_bp, parse_decl, etc.
Interpretor:
    add a new entry to gz_runtime_val if it is an expression
    modify interpretor functionality

*/

GZ_TOKEN_KIND :: enum {
    // Keyword
    GUAN = 0,
    ZHENG,
    IDENTIFIER,

    // LITERAL
    STRING,
    NUMBER,
    // Sign
    LEFT_PARENTHE,
    RIGHT_PARENTHE,
    COLON,
    SEMICOLON,
    PLUS,
    MINUS,
    MULTIPLY,
    DIVIDE,
    PLUSEQUAL,
    MINUSEQUAL,
    EQUAL,
    EQUALEQUAL,
    EOF,

    // new sign
    COUNT,
    NONE,
}

gz_pattern_tuple :: struct {
	pattern: string,
	kind   : GZ_TOKEN_KIND,
}
// Order matters
all_pattern_strings: [dynamic]gz_pattern_tuple = {
	{"(\\s)",                      .NONE},
	{"(guan\\s)",                  .GUAN},
	{"(zheng\\s)",                 .ZHENG},
	{"([a-zA-Z_][\\w]*)",          .IDENTIFIER},
	{"(\\==)",                     .NONE},
	{"(\\+=)",                     .NONE},
	{"(\\-=)",                     .NONE},
	{"(\\=)",                      .EQUAL},
	{"(\\+)",                      .PLUS},
	{"(\\-)",                      .MINUS},
	{"(\\*)",                      .MULTIPLY},
	{"(\\/)",                      .DIVIDE},
	{"([1-9](\\d*))",              .NUMBER},
	{"(0)",                        .NUMBER},
	{"(\\()",                      .LEFT_PARENTHE},
	{"(\\))",                      .RIGHT_PARENTHE},
	{"(\\:)",                      .COLON},
	{"(\\;)",                      .SEMICOLON},
	{"(\"\\w+\")",                 .STRING},
}

// -1 means no bp
bp :: struct {
    l: int,
    r: int,
}

bp_map := make(map[GZ_TOKEN_KIND]bp)
fill_bp_map :: proc(bp_map : ^map[GZ_TOKEN_KIND]bp) {

    // binary expression
    bp_map[.PLUS] = {1, 2}
    bp_map[.MINUS] = {1, 2}
    bp_map[.MULTIPLY] = {3, 4}
    bp_map[.DIVIDE] = {3, 4}
}

gz_node :: struct {
	derived : gz_any_node
}

gz_any_node :: union {

    // expr
    ^gz_binary_expr,
    ^gz_literal_expr,

    // stmt
    ^gz_expr_stmt,
}

gz_any_decl :: union {
    ^gz_val_decl,
}

gz_decl :: struct {
    using decl_base : gz_node,
    derived_decl : gz_any_decl,
}

gz_val_decl :: struct {
    using decl : gz_decl,

}

gz_token :: struct {
    kind : GZ_TOKEN_KIND,
    value: string,
}

gz_lexer :: struct {
    tokens: [dynamic]gz_token,
    index : int,
}

gz_parser :: struct {
    lexer   : ^gz_lexer,
    program : [dynamic]gz_node,
}

gz_expr_stmt :: struct {
    using stmt : gz_stmt,
    expr       : ^gz_expr,
}

gz_any_stmt :: union {
    ^gz_expr_stmt,
}

gz_stmt :: struct {
    using stmt_base : gz_node,
    derived_stmt    : gz_any_stmt,
}

GZ_EXPR :: enum {
        BINARY,
        
        // Literal
        NUMBER_LITERAl
}

gz_any_exp :: union {
    ^gz_binary_expr,
    ^gz_literal_expr,
}

gz_expr :: struct {
    using expr_base : gz_node,
    derived_expr    : gz_any_exp,
}

gz_literal_expr :: struct {
    using expr : gz_expr,
    token      : gz_token,
}

gz_binary_expr :: struct {
    using expr  : gz_expr,
          token : gz_token,
          left  : ^gz_expr,
          right : ^gz_expr,
}

gz_iden :: struct {
    var_name : string
}

gz_runtime_val :: struct {
    val : gz_runtime_type
}

gz_runtime_env :: struct {
    guan_map  : map[string]gz_runtime_val,
    // zheng_map : map[string]gz_func_literal,
    fei_map   : map[string]gz_runtime_val,
}

gz_interpreter :: struct {
    global_env: gz_runtime_env,
}

gz_runtime_type :: union {
    ^string,
    ^int,
    ^f32,
}
