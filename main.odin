package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

file_path : string : "Lang\\1.gz";

GZ_TOKEN_KIND :: enum {
        NUMBER,
        GUAN,
        ZHENG,
}

gz_token_val :: union {
        string,
        f32,
        i32,
}

gz_token :: struct {
        kind  : GZ_TOKEN_KIND,
        value : gz_token_val,
}

tokenize :: proc(file_read : string) -> []gz_token {
        return {}
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

parse :: proc(tokens : []gz_token) -> gz_ast{
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
        fmt.printfln("read: %s", file_read)

        file_string := string(file_read)
        tokens  := tokenize(file_string)
        ast     := parse(tokens)
        interpret_success := interpret(ast)
        if !interpret_success {
                fmt.eprintf("ERROR: interpreter error")
        }

        fmt.printf("Settings\n")
}