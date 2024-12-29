package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:text/regex"

file_path : string : "Lang\\1.gz";

GZ_TOKEN_KIND :: enum {
        NUMBER = 0,
        GUAN,
        ZHENG,
        IDENTIFIER,
        EQUAL,
        COUNT,
        NONE,
}

gz_token :: struct {
        kind  : GZ_TOKEN_KIND,
        value : string,
}

gz_token_val :: union {
        string,
        f32,
        i32,
}

Some_Struct :: struct {
	some_field: int,
}

debug_print_token :: proc(t : gz_token) {
        ti := runtime.type_info_base(type_info_of(type_of(t.kind)))
        info := ti.variant.(runtime.Type_Info_Enum)
        fmt.printf("Token: kind: {}, val: {}\n", info.names[t.kind], t.value)
}

debug_print_token_slice :: proc(t : []gz_token) {
        if len(t) == 0 {
                fmt.printf("No token is provided")
        }
        ti := runtime.type_info_base(type_info_of(type_of(t[0].kind)))
        info := ti.variant.(runtime.Type_Info_Enum)
        fmt.printf("Token: kind: {}, val: {}\n", info.names[t[0].kind], t[0].value)
        
}

debug_print :: proc {
        debug_print_token,
        debug_print_token_slice,
}

gz_lexer :: struct {
        tokens : [dynamic]gz_token
}

gz_pattern_tuple :: struct {
        pattern : string,
        kind : GZ_TOKEN_KIND,
}

all_pattern_strings : [dynamic]gz_pattern_tuple = {
        {"guan\\s" , .GUAN},
        {"zheng\\s", .ZHENG},
        {"=="   , .NONE},
        {"="    , .EQUAL},
        {"\\d+" , .NONE},
        {"\\w+"  , .IDENTIFIER},
        {"\\n"  , .NONE},
        {"\\s"  , .NONE},
}

tokenize :: proc(file_read : string) -> ^gz_lexer {
        // Do regex matching
        patterns : [dynamic]regex.Regular_Expression
        file_read := file_read

        for s in all_pattern_strings {
                pattern, error := regex.create(s.pattern)
                if error != nil {
                        fmt.printf("ERROR: {}", error)
                }
                append_elem(&patterns, pattern)
        }

        lexer := new(gz_lexer)
        
        regex_loop : for {
                matched_any := false;
                for p, index in patterns {
                        cap, matched := regex.match(p, file_read)
                        if matched {
                                matched_any = true
                        }
                        success : bool
                        if len(cap.groups) > 0 && cap.pos[0][0] == 0 {
                                new_token : gz_token
                                new_token.kind = all_pattern_strings[index].kind
                                new_token.value = strings.trim_space(cap.groups[0])
                                fmt.printf("Pattern matched with: %s, size: %d ", all_pattern_strings[index].pattern, len(new_token.value))
                                debug_print(new_token)
                                append_elem(&lexer.tokens, new_token)

                                file_read, success = strings.substring_from(file_read, len(cap.groups[0]))
                                file_read = strings.trim_left_space(file_read)
                                if !success || len(file_read) == 0 {
                                        break regex_loop;
                                }
                                break
                        }
                }
                if !matched_any {
                        fmt.eprintf("Unrecognized token: %s size: {}\n", file_read, len(file_read))
                        break regex_loop
                }
        }

        return lexer
}

GZ_NODE_TYPE :: enum {
        
}

gz_node :: struct {
        left : ^gz_node,
        right : ^gz_node,
        kind : GZ_NODE_TYPE,
        val  : gz_token_val,
}

gz_ast :: struct {
        node : gz_node
}

parse :: proc(lexer : gz_lexer) -> gz_ast{
        assert(false, "NOT IMPLEMENTED")
        return {}
}

interpret :: proc(ast : gz_ast) -> bool {
        return true
}

main :: proc() {
        file_read, success := os.read_entire_file(file_path)
        if !success {
                panic("Cannot read file")
        }
        defer delete(file_read)

        file_string := cast(string)file_read
        fmt.printf("File Read: %s\n", file_string)        

        lexer  := tokenize(file_string)
        ast     := parse(lexer^)
        interpret_success := interpret(ast)
        if !interpret_success {
                fmt.eprintf("ERROR: interpreter error")
        }
}