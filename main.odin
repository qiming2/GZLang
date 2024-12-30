package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:text/regex"
import "base:intrinsics"

file_path: string : "Lang/1.gz"
file_path1: string : "Lang/0.gz"

debug_aprint_type :: proc(t : $T) -> string{
	ti := runtime.type_info_base(type_info_of(type_of(t)))
	// info := ti.variant.(runtime.Type_Info_Enum)
	return fmt.aprintf("{}", ti)
}

debug_print_token :: proc(t: gz_token) {
	ti := runtime.type_info_base(type_info_of(type_of(t.kind)))
	info := ti.variant.(runtime.Type_Info_Enum)
	fmt.printf("Token: kind: {}, val: {}\n", info.names[t.kind], t.value)
}

debug_print_token_slice :: proc(t: []gz_token) {
	if len(t) == 0 {
		fmt.printf("No token is provided")
	}
	ti := runtime.type_info_base(type_info_of(type_of(t[0].kind)))
	info := ti.variant.(runtime.Type_Info_Enum)
	fmt.printf("Token: kind: {}, val: {}\n", info.names[t[0].kind], t[0].value)

}

debug_print :: proc {
	debug_aprint_type,
	debug_print_token,
	debug_print_token_slice,
}

tokenize :: proc(file_read: string) -> ^gz_lexer {
	// Do regex matching
	patterns: [dynamic]regex.Regular_Expression
	file_read := file_read

	for s in all_pattern_strings {
		pattern, error := regex.create(s.pattern)
		if error != nil {
			fmt.printf("ERROR: {}", error)
		}
		append_elem(&patterns, pattern)
	}

	lexer := new(gz_lexer)
        lexer.index = 0

	regex_loop: for {
		matched_any := false
		for p, index in patterns {
			cap, matched := regex.match(p, file_read)
			if matched {
				matched_any = true
			}
			success: bool
			if len(cap.groups) > 0 && cap.pos[0][0] == 0 {
				new_token: gz_token
				new_token.kind = all_pattern_strings[index].kind
				new_token.value = strings.trim_space(cap.groups[0])
				// fmt.printf(
				// 	"Pattern matched with: {}, size: {} ",
				// 	all_pattern_strings[index].pattern,
				// 	len(new_token.value),
				// )
				append_elem(&lexer.tokens, new_token)

				file_read, success = strings.substring_from(file_read, len(cap.groups[0]))
				file_read = strings.trim_left_space(file_read)
				if !success || len(file_read) == 0 {
					break regex_loop
				}
				break
			}
		}
		if !matched_any {
			fmt.eprintf("Unrecognized token: %s size: {}\n", file_read, len(file_read))
			break regex_loop
		}
	}
        append_elem(&lexer.tokens, gz_token{kind=.EOF, value="EOF"})
	return lexer
}

advance :: proc(lex: ^gz_lexer) -> gz_token {
        if len(lex.tokens) == lex.index {
                return {kind=.NONE, value="nil"}
        }

        ret := lex.tokens[lex.index]
        lex.index = lex.index + 1
        return ret
}

peek :: proc(lex: ^gz_lexer) -> gz_token {
        if len(lex.tokens) == lex.index {
                ret := gz_token{.NONE, "nil"}
                return ret
        }

        return lex.tokens[lex.index]
}

create_new_node :: proc($T : typeid) -> ^T{
	node := new(T)
	node.derived = node
	base : ^gz_node = node
	_ = base
	when intrinsics.type_has_field(T, "derived_expr") {
		node.derived_expr = node
	}

	when intrinsics.type_has_field(T, "derived_stmt") {
		node.derived_stmt = node
	}

	return node
}

parse_expr_bp :: proc(parser : ^gz_parser, bp : int) -> ^gz_expr {
	lhs : ^gz_expr
	cur_token := advance(parser.lexer)
	#partial switch cur_token.kind {
	case .NUMBER:
		fallthrough
	case .IDENTIFIER:
		fallthrough
	case .STRING:
		new_expr := create_new_node(gz_literal_expr)
		new_expr.token = cur_token
		lhs = new_expr
		//fmt.printf("{}\n", new_expr^)
	}

	rhs_loop : for {
		cur_token = peek(parser.lexer)
		#partial switch cur_token.kind {

		// infix ops
		case .PLUS, .MINUS, .DIVIDE, .MULTIPLY:
			bp_binary, ok := bp_map[cur_token.kind]
			if !ok {
				panic("No bp for PLUS?\n")
			}
			if bp < bp_binary.l {
				advance(parser.lexer)
				
				rhs := parse_expr_bp(parser, bp_binary.r)

				new_expr := create_new_node(gz_binary_expr)
				new_expr.token = cur_token
				new_expr.left = lhs
				new_expr.right = rhs
				lhs = new_expr
				// fmt.printf("plus_expr: {}\n", new_expr)
				continue
			} 
			break rhs_loop
		case .SEMICOLON:
			// fmt.printf("{}\n", cur_token)
			break rhs_loop
		case .EOF:
			break rhs_loop
		case:
			break rhs_loop
		}
	}
	// fmt.printf("{}\n", lhs^)
	return lhs
}

parser_stmt :: proc(parser: ^gz_parser) -> ^gz_stmt{
	cur_token := peek(parser.lexer)
	#partial switch cur_token.kind {
	case .NUMBER:
		new_stmt := create_new_node(gz_expr_stmt)
		new_expr := parse_expr_bp(parser, bp = 0)
		new_stmt.expr = new_expr
		advance(parser.lexer)
		// fmt.printf("{}\n", new_stmt^)
		return new_stmt
	case .IDENTIFIER:
		return {}
	case .EOF:
		return{};
	}

	return {};
}


parser_start :: proc(parser: ^gz_parser) {
	lexer := parser.lexer
	cur_token := peek(lexer)
	for cur_token.kind != .EOF && cur_token.kind != .NONE {
		append_elem(&parser.program, parser_stmt(parser)^)
		cur_token = peek(lexer)
	}
}

parse :: proc(lexer: ^gz_lexer) -> ^gz_parser {
	fill_bp_map(&bp_map)
	parser := new(gz_parser)
	parser.lexer = lexer
	parser_start(parser)
	return parser
}

walk_node :: proc(node : gz_node, sb : ^strings.Builder) {
	strings.write_byte(sb, ' ')
	defer strings.pop_byte(sb)
	#partial switch n in node.derived {
	case ^gz_binary_expr:
		fmt.printf("{} {} {}\n", strings.to_string(sb^), debug_print(n), n.token)
		walk_node(n.left^, sb)
		walk_node(n.right^, sb)
	case ^gz_literal_expr:
		fmt.printf("{} {} {}\n", strings.to_string(sb^), debug_print(n), n.token)
	case ^gz_expr_stmt:
		fmt.printf("{} {}\n", strings.to_string(sb^), debug_print(n))
		walk_node(n.expr^, sb)
	case:
		fmt.printf("{} {} other derived node not being printed!\n", strings.to_string(sb^), debug_print(n))
	}
}

walk :: proc(program : []gz_node) {
	fmt.printf("Program start: \n")
	sb := strings.Builder{}
	for node in program {
		walk_node(node, &sb)
	}
}

eval :: proc(node : gz_node) -> gz_runtiem_val{
	return {}
}

interpret_start :: proc(program : []gz_node) {
	for node in program {
		fmt.printf("result: {}\n", node, eval(node))
	}
}

interpret :: proc(parser: ^gz_parser) -> bool {
	// walk(parser.program[:])

	interpret_start(parser.program[:])

	return true;
}

main :: proc() {
	file_path, _ := filepath.from_slash(file_path1)
	file_read, success := os.read_entire_file(file_path)
	if !success {
		panic("Cannot read file")
	}
	defer delete(file_read)

	file_string := cast(string)file_read
	//fmt.printf("File Read: %s\n", file_string)

	lexer := tokenize(file_string)
        
    //fmt.printf("size: {}, tokens: {}\n", len(lexer.tokens), lexer.tokens)
        
	parser := parse(lexer)
	interpret_success := interpret(parser)
	if !interpret_success {
		//fmt.eprintf("ERROR: interpreter error")
	}
}
