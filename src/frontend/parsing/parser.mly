/* This is the specification for the parser */

%{
  [@@@coverage exclude_file]
  open Ast.Ast_types
  open Parsed_ast
%}

/* Token definitions */

%token  <int> INT
%token  <string> ID
%token  LPAREN
%token  RPAREN 
%token  LBRACE 
%token  RBRACE 
%token  COMMA 
%token  DOT 
%token  COLON 
%token  SEMICOLON 
%token  EQUAL 
%token  PLUS
%token  MINUS
%token  MULT
%token  DIV
%token  REM
%token  LESS_THAN
%token  GREATER_THAN
%token  AND
%token  OR
%token  EXCLAMATION_MARK
%token  LET 
%token  NEW 
%token  CONST 
%token  VAR 
%token  FUNCTION 
%token  CONSUME 
%token  FINISH 
%token  ASYNC 
%token  CLASS 
%token  REGION 
%token  LINEAR 
%token  THREAD 
%token  READ 
%token  SUBORDINATE 
%token  LOCKED 
%token  TYPE_INT 
%token  TYPE_BOOL
%token  TYPE_VOID
%token  TRUE
%token  FALSE
%token  IF
%token  ELSE
%token  EOF 
%token  FOR
%token  WHILE
%token  MAIN
%token PRINTF
%token <string> STRING


%start program
%type <Parsed_ast.program> program

/* Class defn types */
%type <class_defn> class_defn
%type <capability> capability
%type <region> region
%type <mode> mode
%type <Region_name.t> region_name
%type <Region_name.t list> region_annotations
%type <field_defn> field_defn
%type <param list> params
%type <param> param
%type <method_defn> method_defn

%type <function_defn> function_defn
%type <type_expr> type_expr

%type <block_expr> main_expr
%type <block_expr> block_expr
%type <expr list> args
%type <constructor_arg> constructor_arg
%type <identifier> identifier
%type <expr> simple_expr
%type <expr> expr
%type <async_expr> async_expr

%type <expr> op_expr
%type <un_op> un_op
%type <bin_op> bin_op
%type <expr> bin_op_expr


%%

/* Grammar production 
 * Note: $i refers to the i'th (non)terminal symbol in the rule*/

program: 
| class_defns=list(class_defn); function_defns=list(function_defn); main= main_expr;  EOF {Prog(class_defns, function_defns, main)}


/* Productions related to class definitions */

class_defn:
| CLASS ; name=ID; LBRACE; region=region_defn; field_defns=nonempty_list(field_defn); method_defns=list(method_defn);  RBRACE 
{TClass(Class_name.of_string name, region, field_defns, method_defns)}


/* Capabilities and Regions */
capability:
| LINEAR { Linear }
| THREAD { Thread }
| READ  { Read }
| SUBORDINATE { Subordinate }
| LOCKED { Locked }

region_defn:
| REGION; regions=separated_nonempty_list(COMMA,region); SEMICOLON; {regions}

region:
| cap=capability; reg_name=ID {TRegion(cap, Region_name.of_string reg_name)}


/* Field definitions */

mode:
| CONST {MConst}
| VAR {MVar}

region_name:
| reg_name=ID {Region_name.of_string reg_name}

region_annotations:
| COLON; region_name=region_name {[region_name]}
| COLON; LPAREN; region_names=separated_nonempty_list(COMMA,region_name) RPAREN;{region_names}

field_defn:
| m=mode; field_type=type_expr; field_name=ID; region_names=region_annotations SEMICOLON {TField(m, field_type, Field_name.of_string field_name, region_names)}


/* Method and function definitions */

params:
| LPAREN; params=separated_list(COMMA,param); RPAREN {params}

param:
| param_type=type_expr; param_name=ID; region_guards=option(region_annotations) {TParam(param_type, Var_name.of_string param_name, region_guards)}


method_defn: 
| return_type=type_expr; method_name=ID; method_params=params; effect_regions=region_annotations body=block_expr {TMethod( Method_name.of_string method_name, return_type, method_params,effect_regions,body)}

function_defn: 
| FUNCTION; return_type=type_expr; function_name=ID; function_params=params;  body=block_expr {TFunction(Function_name.of_string function_name, return_type, function_params,body)}


/* Types */

type_expr : 
| class_name=ID {TEClass(Class_name.of_string class_name)} 
| TYPE_INT  {TEInt} 
| TYPE_BOOL {TEBool}
| TYPE_VOID {TEVoid}


/* Expressions */

main_expr:
| TYPE_VOID; MAIN; LPAREN; RPAREN; exprs=block_expr {exprs}

block_expr:
| LBRACE; exprs=separated_list(SEMICOLON, expr); RBRACE {Block($startpos, exprs)}


/* Method / function arguments */
args:
| LPAREN; args=separated_list(COMMA, expr); RPAREN {args}

constructor_arg:
| field_name=ID; COLON; assigned_expr=expr {ConstructorArg(Field_name.of_string field_name, assigned_expr)}


identifier:
| variable=ID {Variable(Var_name.of_string variable)}
| obj=ID DOT field=ID {ObjField(Var_name.of_string obj, Field_name.of_string field)}

simple_expr:
| LPAREN e=expr RPAREN {e}
| i=INT {Integer($startpos, i)}
| TRUE { Boolean($startpos, true)}
| FALSE {  Boolean($startpos, false) }
| id=identifier { Identifier($startpos, id)}

expr:
| op_e=op_expr  {op_e}
/*  Creating / reassigning \ deallocating references */
| NEW; class_name=ID; LPAREN; constr_args=separated_list(COMMA, constructor_arg); RPAREN {Constructor($startpos, Class_name.of_string class_name, constr_args)}
| LET; var_name=ID; EQUAL; bound_expr=expr  {Let($startpos, Var_name.of_string var_name, bound_expr)} 
| id=identifier; COLON; EQUAL; assigned_expr=expr {Assign($startpos, id, assigned_expr)}
| CONSUME; id=identifier {Consume($startpos, id)}
/* Function / Method Application */
| obj=ID; DOT; method_name=ID; method_args=args {MethodApp($startpos, Var_name.of_string obj, Method_name.of_string method_name, method_args)}
| fn=ID; fn_args=args { FunctionApp($startpos, Function_name.of_string fn, fn_args) } 
| PRINTF; LPAREN; format_str=STRING; option(COMMA); args=separated_list(COMMA, expr); RPAREN {Printf($startpos, format_str,args)}
/* Control flow */
| IF; cond_expr=expr; then_expr=block_expr; ELSE; else_expr=block_expr {If($startpos, cond_expr, then_expr, else_expr)}
| WHILE cond_expr=expr; loop_expr=block_expr {While($startpos, cond_expr, loop_expr)}
| FOR; LPAREN; init_expr=expr; SEMICOLON; cond_expr=expr; SEMICOLON; step_expr=expr; RPAREN; loop_expr=block_expr {For($startpos, init_expr, cond_expr, step_expr, loop_expr)}
/* Async expression */
| FINISH; LBRACE; forked_async_exprs=list(async_expr); curr_thread_expr=separated_list(SEMICOLON, expr) RBRACE {FinishAsync($startpos, forked_async_exprs, Block($startpos(curr_thread_expr), curr_thread_expr))}

async_expr:
| ASYNC exprs=block_expr {AsyncExpr exprs}


/* Operator expressions */

op_expr:
| op=un_op e=simple_expr {UnOp($startpos,op,e)}
| bin_op_expr=bin_op_expr {bin_op_expr}

un_op:
| EXCLAMATION_MARK {UnOpNot}
| MINUS {UnOpNeg}

bin_op:
| PLUS { BinOpPlus }
| MINUS { BinOpMinus }
| MULT { BinOpMult }
| DIV { BinOpIntDiv } 
| REM { BinOpRem }
| LESS_THAN { BinOpLessThan }
| LESS_THAN EQUAL { BinOpLessThanEq }
| GREATER_THAN { BinOpGreaterThan }
| GREATER_THAN EQUAL{ BinOpGreaterThanEq }
| AND {BinOpAnd}
| OR {BinOpOr}
| EQUAL EQUAL {BinOpEq}
| EXCLAMATION_MARK EQUAL {BinOpNotEq}


bin_op_expr:
| e1=bin_op_expr op=bin_op e2=simple_expr {BinOp($startpos, op, e1, e2)}
| e=simple_expr {e}
