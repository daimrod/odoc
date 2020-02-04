open Component

exception Find_failure of Signature.t * string * string

let fail sg name ty = raise (Find_failure (sg, name, ty))

type class_type = [ `C of Class.t | `CT of ClassType.t ]

type type_ = [ `T of TypeDecl.t | class_type ]

type value = [ `V of Value.t | `E of External.t ]

type ('a, 'b) found = Found of 'a | Replaced of 'b

let careful_module_in_sig s name =
  let rec inner_removed = function
    | Signature.RModule (id, p) :: _ when Ident.Name.module_ id = name ->
        Replaced p
    | _ :: rest -> inner_removed rest
    | [] -> fail s name "module"
  in
  let rec inner = function
    | Signature.Module (id, _, m) :: _ when Ident.Name.module_ id = name ->
        Found (Delayed.get m)
    | Signature.Include i :: rest -> (
        try inner i.Include.expansion_.items with _ -> inner rest )
    | _ :: rest -> inner rest
    | [] -> inner_removed s.removed
  in
  inner s.items

let careful_type_in_sig s name =
  let rec inner_removed = function
    | Signature.RType (id, p) :: _ when Ident.Name.type_ id = name ->
        Format.fprintf Format.err_formatter "Found replaced type %a\n%!"
          Ident.fmt id;
        Replaced p
    | _ :: rest -> inner_removed rest
    | [] -> fail s name "type"
  in
  let rec inner = function
    | Signature.Type (id, _, m) :: _ when Ident.Name.type_ id = name ->
        Found (`T m)
    | Signature.Class (id, _, c) :: _ when Ident.Name.class_ id = name ->
        Found (`C c)
    | Signature.ClassType (id, _, c) :: _ when Ident.Name.class_type id = name
      ->
        Found (`CT c)
    | Signature.Include i :: rest -> (
        try inner i.Include.expansion_.items with _ -> inner rest )
    | _ :: rest -> inner rest
    | [] -> inner_removed s.removed
  in
  inner s.items

let module_in_sig s name =
  match careful_module_in_sig s name with
  | Found m -> m
  | Replaced _ -> fail s name "module"

let opt_module_in_sig s name =
  match careful_module_in_sig s name with
  | Found m -> Some m
  | Replaced _ -> None
  | exception _ -> None

let module_type_in_sig s name =
  let rec inner = function
    | Signature.ModuleType (id, m) :: _ when Ident.Name.module_type id = name
      ->
        Delayed.get m
    | Signature.Include i :: rest -> (
        try inner i.Include.expansion_.items with _ -> inner rest )
    | _ :: rest -> inner rest
    | [] -> fail s name "module type"
  in
  inner s.items

let opt_module_type_in_sig s name =
  try Some (module_type_in_sig s name) with _ -> None

let opt_value_in_sig s name : value option =
  let rec inner = function
    | Signature.Value (id, m) :: _ when Ident.Name.value id = name ->
        Some (`V m)
    | Signature.External (id, e) :: _ when Ident.Name.value id = name ->
        Some (`E e)
    | Signature.Include i :: rest -> (
        match inner i.Include.expansion_.items with
        | Some m -> Some m
        | None -> inner rest )
    | _ :: rest -> inner rest
    | [] -> None
  in

  inner s.Signature.items

let type_in_sig s name =
  match careful_type_in_sig s name with
  | Found t -> t
  | Replaced _ -> fail s name "type"

let opt_type_in_sig s name =
  match careful_type_in_sig s name with
  | Found t -> Some t
  | Replaced _ -> None
  | exception _ -> None

let class_type_in_sig s name =
  let rec inner = function
    | Signature.Class (id, _, c) :: _ when Ident.Name.class_ id = name -> `C c
    | Signature.ClassType (id, _, c) :: _ when Ident.Name.class_type id = name
      ->
        `CT c
    | Signature.Include i :: rest -> (
        try inner i.Include.expansion_.items with _ -> inner rest )
    | _ :: rest -> inner rest
    | [] -> fail s name "class type"
  in
  inner s.items

let opt_label_in_sig s name =
  let rec inner = function
    | Signature.Comment (`Docs d) :: rest -> (
        let rec inner' xs =
          match xs with
          | elt :: rest -> (
              match elt with
              | `Heading (_, label, _) when Ident.Name.label label = name ->
                  Some label
              | _ -> inner' rest )
          | _ -> None
        in
        match inner' d with None -> inner rest | x -> x )
    | Signature.Include i :: rest -> (
        match inner i.Include.expansion_.items with
        | Some _ as x -> x
        | None -> inner rest )
    | _ :: rest -> inner rest
    | [] -> None
  in
  inner s.Signature.items