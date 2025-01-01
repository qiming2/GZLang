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

debug_aprint_type :: proc(t : $T) -> string {
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
	debug_print_token,
	debug_print_token_slice,
	debug_aprint_type,
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

expect :: proc(lex: ^gz_lexer, kind: GZ_TOKEN_KIND, message: string = "Default Error") -> gz_token{
	cur := advance(lex)
	if cur.kind != kind {
		panic(fmt.aprintf("Message: %v, not: %v", message, cur))
	}
	return cur
}

peek :: proc(lex: ^gz_lexer) -> gz_token {
        if len(lex.tokens) == lex.index {
                ret := gz_token{.NONE, "nil"}
                return ret
        }

        return lex.tokens[lex.index]
}

peek_next :: proc(lex: ^gz_lexer) -> gz_token {
	if len(lex.tokens) == lex.index + 1 {
		ret := gz_token{.NONE, "nil"}
		return ret
	}

	return lex.tokens[lex.index + 1]
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
	case .IDENTIFIER:
		new_expr := create_new_node(gz_iden_expr)
		new_expr.ident = cur_token.value
		lhs = new_expr
	case .STRING, .NUMBER:
		new_expr := create_new_node(gz_literal_expr)
		new_expr.token = cur_token
		lhs = new_expr
	case:
		panic(fmt.aprintf("Invalid token during parse expression found: %v\n", cur_token))
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

parse_field_list :: proc(parser: ^gz_parser, field_list: ^[dynamic]string) {

}

parse_func_body :: proc(parser: ^gz_parser, func_del: ^gz_func_decl) {
	lexer := parser.lexer
	cur_token := peek(lexer)
	for cur_token.kind != .RIGHT_CURLY {
		if cur_token.kind == .EOF || cur_token.kind == .NONE {
			panic("No curly brace provided for func body")
		}
		parsed_stmt := parse_stmt(parser)
		if parsed_stmt != nil {
			append_elem(&func_del.body, parsed_stmt)
		}
		cur_token = peek(lexer)
	}
}

parser_zheng_call_list_exprs :: proc(arg_exprs: ^[dynamic]^gz_expr) {

}

parse_stmt :: proc(parser: ^gz_parser) -> ^gz_stmt{
	cur_token := peek(parser.lexer)
	#partial switch cur_token.kind {
	case .NUMBER:
		new_stmt := create_new_node(gz_expr_stmt)
		new_expr := parse_expr_bp(parser, bp = 0)
		new_stmt.expr = new_expr
		// fmt.printf("{}\n", new_stmt^)
		expect(parser.lexer, .SEMICOLON, "Not end with a semicolon")
		return new_stmt
	case .GUAN:
		advance(parser.lexer)
		new_stmt := create_new_node(gz_var_decl)
		new_stmt.ident = expect(parser.lexer, .IDENTIFIER, "Need to provide a valid name as variable name").value
		new_stmt.is_const = false
		expect(parser.lexer, .EQUAL, "Needs an assignment sign")
		new_stmt.expr = parse_expr_bp(parser, bp = 0)
		expect(parser.lexer, .SEMICOLON, "Not end with a semicolon")
		return new_stmt
	case .FEI:
		advance(parser.lexer)
		new_stmt := create_new_node(gz_var_decl)
		new_stmt.ident = expect(parser.lexer, .IDENTIFIER, "Need to provide a variable name").value
		new_stmt.is_const = true
		expect(parser.lexer, .EQUAL, "Needs an assignment sign")
		new_stmt.expr = parse_expr_bp(parser, bp = 0)
		expect(parser.lexer, .SEMICOLON, "Not end with a semicolon")
		return new_stmt
	case .ZHENG:
		fmt.printf("Entered ZHENG parsing branch\n")
		advance(parser.lexer)
		new_stmt := create_new_node(gz_func_decl)
		new_stmt.ident = expect(parser.lexer, .IDENTIFIER, "Need to provide a variable name").value
		expect(parser.lexer, .LEFT_PAREN, "Need to enclose args with parentheses")
		// Parser func literal arg list
		parse_field_list(parser, &new_stmt.arg_list)
		expect(parser.lexer, .RIGHT_PAREN, "Need to enclose args with parentheses")
		expect(parser.lexer, .LEFT_CURLY, "Need to enclose func body with curly brackets")
		parse_func_body(parser, new_stmt)
		expect(parser.lexer, .RIGHT_CURLY, "Need to enclose func body with curly brackets")
		return new_stmt
	case .IDENTIFIER:
		next_tok := peek_next(parser.lexer)
		#partial switch next_tok.kind {
		case .EQUAL:
			// Assignment stmt
			advance(parser.lexer)
			new_stmt := create_new_node(gz_assign_stmt)
			new_stmt.ident = cur_token.value
			expect(parser.lexer, .EQUAL, "Needs an assignment sign")
			new_stmt.expr = parse_expr_bp(parser, bp = 0)
			expect(parser.lexer, .SEMICOLON, "Not end with a semicolon")
			return new_stmt
		case .LEFT_PAREN:
			// call expr
			// pass identifier
			advance(parser.lexer)
			// pass left parenthesis
			advance(parser.lexer)
			new_stmt := create_new_node(gz_expr_stmt)
			new_expr := create_new_node(gz_call_expr)
			new_expr.ident = cur_token.value
			parser_zheng_call_list_exprs(&new_expr.arg_exprs)
			expect(parser.lexer, .RIGHT_PAREN, fmt.aprintf("Zheng func: %v call args need to be enclosed with paretheses!", cur_token.value))
			expect(parser.lexer, .SEMICOLON, "Not end with a semicolon")
			new_stmt.expr = new_expr
			return new_stmt
		case:
			// Not a stmt and pass it to the expr
			new_stmt := create_new_node(gz_expr_stmt)
			new_stmt.expr = parse_expr_bp(parser, bp = 0)
			// fmt.printf("{}\n", new_stmt^)
			expect(parser.lexer, .SEMICOLON, "Not end with a semicolon")
			return new_stmt
		}
	case .SEMICOLON:
		advance(parser.lexer)
		return nil
	case:
		panic(fmt.aprintf("Unknown started token in parse_stmt %v\n", cur_token))
	}
	return nil
}


parser_start :: proc(parser: ^gz_parser) {
	lexer := parser.lexer
	cur_token := peek(lexer)
	for cur_token.kind != .EOF && cur_token.kind != .NONE {
		parsed_stmt := parse_stmt(parser)
		if parsed_stmt != nil {
			append_elem(&parser.program, parsed_stmt)
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

walk_node_default :: proc(node: ^gz_node) {
	fmt.printf("Start walking node: \n")
	sb := strings.Builder{}
	walk_node(node, &sb)
}

walk_node_with_builder :: proc(node: ^gz_node, sb : ^strings.Builder) {
	strings.write_byte(sb, ' ')
	defer strings.pop_byte(sb)
	#partial switch n in node.derived {
	case ^gz_binary_expr:
		fmt.printf("{} {} {}\n", strings.to_string(sb^), debug_print(n), n.token)
		walk_node(n.left, sb)
		walk_node(n.right, sb)
	case ^gz_literal_expr:
		fmt.printf("{} {} {}\n", strings.to_string(sb^), debug_print(n), n.token)
	case ^gz_expr_stmt:
		fmt.printf("{} {}\n", strings.to_string(sb^), debug_print(n))
		walk_node(n.expr, sb)
	case ^gz_var_decl:
		fmt.printf("{} {}\n", strings.to_string(sb^), n.ident)
		walk_node(n.expr, sb)
	case:
		fmt.printf("{} {} other derived node not being interpreted!\n", strings.to_string(sb^), n)
	}
}

walk :: proc(program : []^gz_node) {
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

eval :: proc(env: ^gz_runtime_env, node : ^gz_node) -> (ret: gz_runtime_val, success: bool) {
	ret = {nil, false}
	success = false
	#partial switch n in node.derived {
	case ^gz_binary_expr:		
		left_val , success_eval_left := eval(env, n.left)
		if !success_eval_left {
			fmt.printf("Left eval failed\n")
			return
		}
		right_val, success_eval_right := eval(env, n.right)
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
	case ^gz_iden_expr:
		ret, success = get_var(env, n.ident, false)
		if success {
			return
		}

		ret, success = get_var(env, n.ident, true)
		if success {
			return
		}
		panic(fmt.aprintf("Variable used before declaration: %v\n", n.ident))
	case ^gz_literal_expr:
		ret, success = is_literal(n.token)
		return 
	case ^gz_expr_stmt:
		ret, success = eval(env, n.expr)
		if !success {
			fmt.printf("Malformed stmt: %v", n)
		}
		return
	case ^gz_func_decl:
		if exist_var(env, n.ident) {
			panic(fmt.aprintf("Redeclaration of variable: %v\n", n.ident))
		}

		ret, success = {n, true}, true
		set_var(env, n.ident, ret)
		fmt.printf("Stored func : %v, value: %v, is const: %v\n", n.ident, ret, true)
		return
	case ^gz_call_expr:
		runtime_val, success_get_call_expr := get_var(env, n.ident)
		if !success_get_call_expr {
			panic(fmt.aprintf("Func: %v not declared!\n", n.ident))
		}

		func, ok := runtime_val.val.(^gz_func_decl)
		if !ok {
			panic(fmt.aprintf("%v is not a zheng func!\n", n.ident))
		}

		interpret_start(env, transmute([]^gz_node)(func.body[:]))
		return runtime_val, true
	case ^gz_var_decl:
		if exist_var(env, n.ident) {
			panic(fmt.aprintf("Redeclaration of: %s\n", n.ident))
		}

		ret, success = eval(env, n.expr)
		ret.is_const = n.is_const
		if !success {
			fmt.printf("Malformed expression on right hand side: %v", n)
			return
		}
		set_var(env, n.ident, ret)
		fmt.printf("Stored var : %v, value: %v, is const: %v\n", n.ident, ret, n.is_const)
		return
	case ^gz_assign_stmt:
		ret, success = get_var(env, n.ident)
		if !success || ret.is_const {
			panic(fmt.aprintf("Can not assign a val to a non-existent var or const var: %s\n", n.ident))
		}

		ret, success = eval(env, n.expr)
		if !success {
			panic(fmt.aprintf("Expression evaluation failed when assigning to a variable %s\n", n.ident))
		}
		set_var(env, n.ident, ret)
		return
	case:
		fmt.printf("{} can not interpret node!\n", n)
		return
	}

	return
}

interpret_start :: proc(env: ^gz_runtime_env, program : []^gz_node) {
	for node in program {
		result, success := eval(env, node)
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
		case ^gz_func_decl:
			fmt.printf("result: assigned function literal to %v\n", res.ident)
		}
	}
}

interpret_one_shot :: proc(parser: ^gz_parser) -> bool {

	inter := new(gz_interpreter)
	interpret_start(&inter.global_env, parser.program[:])

	return true;
}

interpret_continuous :: proc(inter: ^gz_interpreter, code: string) {
	lexer := tokenize(code)
	defer free(lexer)
	parser := parse(lexer)
	defer free(parser)
	interpret_start(&inter.global_env, parser.program[:])
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

		for tok in lexer.tokens {
			debug_print_token(tok)
		}
			
		// Parser step
		// fmt.printf("???\n")
		parser := parse(lexer)
		defer free(parser)

		interpret_success := interpret(parser)
		if !interpret_success {
			fmt.eprintf("ERROR: interpreter error\n")
		}
	}
	
	// fmt.printf("???\n")
}
