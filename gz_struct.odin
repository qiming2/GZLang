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
    FEI,
    ZHENG,
    IDENTIFIER,

    // LITERAL
    STRING,
    NUMBER,
    // Sign
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_CURLY,
    RIGHT_CURLY,
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
all_pattern_strings: []gz_pattern_tuple = {
	{"(^\\s)",                      .NONE},
	{"(^guan[\\s;])",               .GUAN},
	{"(^fei[\\s;])",                .FEI},
	{"(^zheng[\\s;])",              .ZHENG},
	{"(^[a-zA-Z_][\\w]*)",          .IDENTIFIER},
	{"(^\\==)",                     .NONE},
	{"(^\\+=)",                     .NONE},
	{"(^\\-=)",                     .NONE},
	{"(^\\=)",                      .EQUAL},
	{"(^\\+)",                      .PLUS},
	{"(^\\-)",                      .MINUS},
	{"(^\\*)",                      .MULTIPLY},
	{"(^\\/)",                      .DIVIDE},
	{"(^(\\d*)(\\.)(\\d*))",        .NUMBER},
	{"(^[1-9](\\d*))",              .NUMBER},
	{"(^0)",                        .NUMBER},
	{"(^\\()",                      .LEFT_PAREN},
	{"(^\\))",                      .RIGHT_PAREN},
	{"(^\\{)",                      .LEFT_CURLY},
	{"(^\\})",                      .RIGHT_CURLY},
	{"(^\\:)",                      .COLON},
	{"(^\\;)",                      .SEMICOLON},
	{"(^\"\\w+\")",                 .STRING},
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
    ^gz_iden_expr,
    ^gz_call_expr,

    // stmt
    ^gz_expr_stmt,
    ^gz_assign_stmt,

    // decl
    ^gz_var_decl,
    ^gz_func_decl,
}

gz_decl :: struct {
    using decl_base : gz_stmt,
}

gz_var_decl :: struct {
    using decl : gz_decl,
    ident      : string,
    expr       : ^gz_expr,
    is_const   : bool,
}

gz_func_decl :: struct {
    using decl : gz_decl,
    body : [dynamic]^gz_stmt,
    ident : string,
    arg_list : [dynamic]string,
    ret_num : int,
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
    program : [dynamic]^gz_node,
}

gz_expr_stmt :: struct {
    using stmt : gz_stmt,
    expr       : ^gz_expr,
}

gz_assign_stmt :: struct {
    using stmt : gz_stmt,
    ident      : string,
    expr       : ^gz_expr,
}

gz_any_stmt :: union {

    // stmt
    ^gz_expr_stmt,
    ^gz_assign_stmt,

    // decl
    ^gz_var_decl,
    ^gz_func_decl,
    
}

gz_stmt :: struct {
    using stmt_base : gz_node,
    derived_stmt    : gz_any_stmt,
}

gz_any_expr :: union {
    ^gz_binary_expr,
    ^gz_literal_expr,
    ^gz_iden_expr,
    ^gz_call_expr,
}

gz_expr :: struct {
    using expr_base : gz_node,
    derived_expr    : gz_any_expr,
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

gz_call_expr :: struct {
    using expr : gz_expr,
    ident      : string,
    arg_exprs  : [dynamic]^gz_expr
}

gz_iden_expr :: struct {
    using expr : gz_expr,
    ident      : string,
}

gz_runtime_val :: struct {
    val : gz_runtime_type,
    is_const : bool,
}

gz_runtime_env :: struct {
    var_map : map[string]gz_runtime_val,
    parent : ^gz_runtime_env,
}

get_var :: proc(env: ^gz_runtime_env, ident: string, is_const : bool = false) -> (ret : gz_runtime_val, success : bool) {
    ret, success = env.var_map[ident]
    return ret, success
}

exist_var :: proc(env: ^gz_runtime_env, ident: string) -> (success : bool) {
    _, success = env.var_map[ident]
    return success
}

set_var :: proc(env: ^gz_runtime_env, ident: string, val: gz_runtime_val) {
    env.var_map[ident] = val
}

gz_interpreter :: struct {
    global_env: gz_runtime_env,
}

gz_runtime_type :: union {
    ^string,
    ^int,
    ^f32,
    ^gz_func_decl,
}
