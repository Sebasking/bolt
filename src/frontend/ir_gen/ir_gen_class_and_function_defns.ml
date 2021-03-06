open Core
open Ir_gen_env
open Ir_gen_expr

let ir_gen_type = function
  | Ast.Ast_types.TEBool -> Frontend_ir.TEBool
  | Ast.Ast_types.TEInt -> Frontend_ir.TEInt
  | Ast.Ast_types.TEVoid -> Frontend_ir.TEVoid
  | Ast.Ast_types.TEClass (class_name, _) ->
      Frontend_ir.TEClass (Ast.Ast_types.Class_name.to_string class_name)
  | Ast.Ast_types.TEGeneric ->
      (* shouldn't occur as desugared earlier - we throw exn to avoid tainting type *)
      raise (Ast.Ast_types.NotDesugaredGenericType "IR Lowering")

let ir_gen_param = function
  | Ast.Ast_types.TParam (param_type, param_name, _, _) ->
      Frontend_ir.TParam
        (ir_gen_type param_type, Ast.Ast_types.Var_name.to_string param_name)

let ir_gen_field_defn (Ast.Ast_types.TField (_, field_type, _, _)) =
  ir_gen_type field_type

let ir_gen_class_defn class_defns
    (Desugaring.Desugared_ast.TClass (class_name, _, _, _, _)) =
  List.map ~f:ir_gen_field_defn (get_class_fields class_name class_defns)
  |> fun ir_fields ->
  ir_gen_vtable class_name class_defns
  |> fun ir_vtable ->
  Frontend_ir.TClass (Ast.Ast_types.Class_name.to_string class_name, ir_fields, ir_vtable)

let ir_gen_class_defns class_defns =
  List.map ~f:(ir_gen_class_defn class_defns) class_defns

let ir_gen_class_method_defn class_defns class_name
    (Desugaring.Desugared_ast.TMethod
      ( method_name
      , _
      (* drop info about whether returning borrowed ref *)
      , return_type
      , params
      , capabilities_used
      , body_expr )) =
  let open Result in
  let obj_type = Ast.Ast_types.TEClass (class_name, None) in
  ir_gen_method_name method_name class_name
  |> fun ir_method_name ->
  ir_gen_type return_type
  |> fun ir_return_type ->
  Frontend_ir.TParam (ir_gen_type obj_type, "this") :: List.map ~f:ir_gen_param params
  |> fun ir_params ->
  ir_gen_block_expr class_defns body_expr
  >>| fun ir_body_expr ->
  let maybe_locked_ir_body_expr =
    match
      List.filter
        ~f:(fun (Ast.Ast_types.TCapability (mode, _)) -> mode = Ast.Ast_types.Locked)
        capabilities_used
    with
    | []     -> ir_body_expr
    | _ :: _ ->
        [ Frontend_ir.Lock ("this", Frontend_ir.Writer)
        ; Frontend_ir.Let ("_ret_val", Frontend_ir.Block ir_body_expr)
        ; Frontend_ir.Unlock ("this", Frontend_ir.Writer)
        ; Frontend_ir.Identifier (Frontend_ir.Variable "_ret_val", None) ] in
  Frontend_ir.TFunction
    (ir_method_name, ir_return_type, ir_params, maybe_locked_ir_body_expr)

let ir_gen_class_method_defns class_defns
    (Desugaring.Desugared_ast.TClass (class_name, _, _, _, method_defns)) =
  Result.all (List.map ~f:(ir_gen_class_method_defn class_defns class_name) method_defns)

let ir_gen_function_defn class_defns
    (Desugaring.Desugared_ast.TFunction
      ( func_name
      , _
      (* drop info about whether returning borrowed ref *)
      , return_type
      , params
      , body_expr )) =
  let open Result in
  ir_gen_type return_type
  |> fun ir_return_type ->
  List.map ~f:ir_gen_param params
  |> fun ir_params ->
  ir_gen_block_expr class_defns body_expr
  >>| fun ir_body_expr ->
  Frontend_ir.TFunction
    ( Ast.Ast_types.Function_name.to_string func_name
    , ir_return_type
    , ir_params
    , ir_body_expr )

let ir_gen_function_defns class_defns function_defns =
  let open Result in
  Result.all (List.map ~f:(ir_gen_class_method_defns class_defns) class_defns)
  >>= fun ir_classes_method_defns ->
  Result.all (List.map ~f:(ir_gen_function_defn class_defns) function_defns)
  >>| fun ir_function_defns -> List.concat (ir_function_defns :: ir_classes_method_defns)
