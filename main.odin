package main

import "base:runtime"
import "base:intrinsics"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:text/regex"
import "core:strconv"

file_path0: string : "Lang/0.gz"
file_path1: string : "Lang/1.gz"
file_path2: string : "Lang/2.gz"

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
			fmt.eprintf("Unrecognized token: %v size: {}\n", file_read, len(file_read))
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

expect :: proc(lex: ^gz_lexer, kind: GZ_TOKEN_KIND, message: string = "Default Error") {
	cur := advance(lex)
	if cur.kind != kind {
		panic(fmt.aprintf("Message: %v", message))
	}
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
			fmt.printf("Hello? {}\n", cur_token)
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
		expect(parser.lexer, .SEMICOLON, "Not end with a semicolon")
		// fmt.printf("{}\n", new_stmt^)
		return new_stmt
	case .GUAN:
		fmt.printf("GUAN decl stmt!\n")
		new_stmt := create_new_node(gz_expr_stmt)
		advance(parser.lexer)
		return new_stmt
	case:
		fmt.printf("Unknown started token in parser_stmt %v\n", cur_token)
		advance(parser.lexer)
		return nil
	}
	return nil
}


parser_start :: proc(parser: ^gz_parser) {
	lexer := parser.lexer
	cur_token := peek(lexer)
	for cur_token.kind != .EOF && cur_token.kind != .NONE {
		parsed_stmt := parser_stmt(parser)
		if parsed_stmt != nil {
			append_elem(&parser.program, parsed_stmt^)
		}
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

walk_node :: proc {
	walk_node_with_builder,
	walk_node_default,
}

walk_node_default :: proc(node: gz_node) {
	fmt.printf("Start walking node: \n")
	sb := strings.Builder{}
	walk_node(node, &sb)

}

walk_node_with_builder :: proc(node: gz_node, sb : ^strings.Builder) {
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

is_literal :: proc(token : gz_token) -> (val: gz_runtime_val, success: bool) {
	val = {}
	success = false
	#partial switch token.kind {
	case .NUMBER:
		float_val, success_float := strconv.parse_f32(token.value)
		if !success_float {
			fmt.printf("string to f32 failed?: {}\n", token.value)
		}
		float_ptr := new(f32)
		float_ptr^ = float_val
		val.val = gz_runtime_type(float_ptr)
		success = success_float
		// fmt.printf("string to f32 passed: {}\n", token.value)
		return
	case .STRING:
		string_ptr := new(string)
		string_ptr^ = token.value
		val.val = string_ptr
		success = true
		fmt.printf("String literal type: {}", token.value)
		return
	case:
		fmt.printf("None literal type: {}", token.value)
		return
	}
	fmt.printf("None literal type: {}", token.value)
	return
}

is_number :: proc {
	is_number_for_runtime,
	is_number_for_token,
}

is_number_for_token :: proc(token : gz_token) -> (ret_a: f32, success: bool) {
	ret_a = 0
	success = false

	#partial switch token.kind {
	case .NUMBER:
		ret_a, success = strconv.parse_f32(token.value)
		return
	case:
		return
	}

	return
}

is_number_for_runtime :: proc(a : gz_runtime_val) -> (ret_a: f32, success: bool) {
	ret_a = 0
	success = false
	#partial switch v in a.val {
	case ^int:
		ret_a = f32(v^)
		success = true
		return 
	case ^f32:
		ret_a = v^
		success = true
		return
	case:
		fmt.printf("runtime val is not a number: {}", a)
		return
	}
	fmt.printf("runtime val is not a number: {}", a)
	return
}

are_both_numbers :: proc(a : gz_runtime_val, b : gz_runtime_val) -> (ret_a : f32, ret_b : f32, success : bool){
	ret_a = 0.0
	ret_b = 0.0
	success = true
	ret_a, success = is_number(a)
	ret_b, success = is_number(b)
	return;
}

eval :: proc(node : gz_node) -> (ret: gz_runtime_val, success: bool) {
	ret = {}
	success = false
	#partial switch n in node.derived {
	case ^gz_binary_expr:
		
		left_val , success_eval_left := eval(n.left^)
		if !success_eval_left {
			fmt.printf("Left eval failed\n")
			return
		}
		right_val, success_eval_right := eval(n.right^)
		if !success_eval_right {
			fmt.printf("Right eval failed\n")
			return
		}
		#partial switch n.token.kind {
		case .PLUS:
			a, b, success_plus := are_both_numbers(left_val, right_val)
			if !success_plus {
				panic("Different types or one of the types is not a number!\n")
			}
			val := new(f32)
			val^ = a + b
			ret.val = val
			return ret, success_plus
		case .MINUS:
			a, b, success_minus := are_both_numbers(left_val, right_val)
			if !success_minus {
				panic("Different types or one of the types is not a number!\n")
			}
			val := new(f32)
			val^ = a - b
			ret.val = val
			return ret, success_minus
		case .MULTIPLY:
			a, b, success_mul := are_both_numbers(left_val, right_val)
			if !success_mul {
				panic("Different types or one of the types is not a number!\n")
			}
			val := new(f32)
			val^ = a * b
			ret.val = val
			return ret, success_mul
		case .DIVIDE:
			a, b, success_div := are_both_numbers(left_val, right_val)
			if !success_div {
				panic("Different types or one of the types is not a number!\n")
			}
			val := new(f32)
			val^ = a / b
			ret.val = val
			return ret, success_div
		case:
			fmt.printf("Unknown binary operation\n")
			return ret, success
		}
	case ^gz_literal_expr:
		ret, success = is_literal(n.token)
		return 
	case ^gz_expr_stmt:
		ret, success = eval(n.expr^)
		return
	case:
		fmt.printf("{} can not interpret node!\n", debug_print(n))
		return
	}

	return
}

interpret_start :: proc(inter: ^gz_interpreter, program : []gz_node) {
	for node in program {
		result, success := eval(node)
		if !success {
			fmt.printf("Eval failed: walk node\n")
			walk_node(node)
			return
		}

		switch res in result.val {
		case ^int:
			fmt.printf("result: {}\n", res^)
		case ^string:
			fmt.printf("result: {}\n", res^)
		case ^f32:
			fmt.printf("result: {}\n", res^)
		}
	}
}

interpret_one_shot :: proc(parser: ^gz_parser) -> bool {

	inter := new(gz_interpreter)
	interpret_start(inter, parser.program[:])

	return true;
}

interpret_continuous :: proc(inter: ^gz_interpreter, code: string) {
	lexer := tokenize(code)
	fmt.printf("%v\n", lexer.tokens)
	defer free(lexer)
	parser := parse(lexer)
	defer free(parser)
	interpret_start(inter, parser.program[:])
}

interpret :: proc {
	interpret_one_shot,
	interpret_continuous,
}

main :: proc() {
	is_realtime := false

	file_path, _ := filepath.from_slash(file_path2)
	if len(os.args) == 1 {
		fmt.printf("<File> with .gz extension not provided, would go into real-time mode\n")
		is_realtime = true
	} else {
		fmt.printf("Program: {}, fileName: {}.\n", os.args[0], os.args[1])
		file_path = os.args[1]
	}

	if is_realtime {
		fmt.printf("Welcome to GZ lang v0.0.1: \n")
		inter := new(gz_interpreter)
		Interpret_loop: for {
			sb := strings.builder_make(256)
			read_buf : [256]u8
			_ = read_buf
			fmt.printf("> ")
			n, err := os.read(os.stdin, sb.buf[:])
			if err != nil {
				fmt.eprintln("Error reading: ", err)
				os.exit(1)
			}
			
			sb.buf[n-1] = ';'
			code := string(sb.buf[:n])
			fmt.printf(code)
			interpret(inter, code)
		}
	} else {
		file_read, success := os.read_entire_file(file_path)
		if !success {
			panic(fmt.aprintf("Cannot read file: %s\n", file_path))
		}
		defer delete(file_read)
	
		file_string := string(file_read)
	
		// Lexer step
		lexer := tokenize(file_string)
		defer free(lexer)
		// for tok in lexer.tokens {
		// 	fmt.printf("token: {}\n", tok)
		// }
		fmt.printf("Lexer Tokens: %v\n", lexer.tokens)
			
		// Parser step
		// fmt.printf("???\n")
		parser := parse(lexer)
		defer free(parser)
		
		fmt.printf("%v\n", parser)
		// walk(parser.program[:])

		interpret_success := interpret(parser)
		if !interpret_success {
			fmt.eprintf("ERROR: interpreter error\n")
		}
	}
	
	// fmt.printf("???\n")
}
