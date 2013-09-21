open Aurochs_pack
open Peg
open Sset
open Types
open Utility
open Vx

(*************************************************************************
 * high level string -> [string] interface
 * ***********************************************************************)

let anagrams_of_string dawg str = Search.anagrams dawg (Bag.of_string str);;

let patterns_of_string dawg str = Search.pattern dawg (Search.trail_of_string str);;

let build_of_string dawg str = Search.all_words dawg (Bag.of_string str);;


(*************************************************************************
 * parser and evaluator
 * ***********************************************************************)

(* types *)

type uop = Anagram | Build | Pattern ;;
type bop = Union | Inter | Diff ;;
type rack = Rack of string;;

type elem = Nop | Primitive of uop * rack | Words of string list

let list_of_elem e = e

let set_of_elem e =
  Sset.of_list (List.map String.lowercase (list_of_elem e))

(* environment *)

type operator = {
  proc: uop;
  desc: string;
  sort: string list -> string list;
};;

type env = {
  mutable operator: operator;
  dawg: Dawg.dawg;
}

let anag, patt, rack =
  { desc = "anagram > "; proc = Anagram; sort = sort_by caps_in; },
  { desc = "pattern > "; proc = Pattern; sort = sort_by caps_in; },
  { desc = "build > "; proc = Build; sort = sort_by String.length; }

let operator_of_uop o = match o with
| Anagram -> anag
| Pattern -> patt
| Build -> rack


(* operator parsing *)

let unary_of op =
  match (String.lowercase op) with
  | "a" -> Anagram
  | "p" -> Pattern
  | "b" -> Build
  | _ -> failwith "no such operation!"

let binary_of op =
  match (String.lowercase op) with
  | "&" | "and"  -> Inter
  | "|" | "or"   -> Union
  | "-" | "diff" -> Diff
  | _ -> failwith "no such operation!"

(* evaluation *)

let unary env o r =
  let p = match o with
  | Anagram -> anagrams_of_string
  | Pattern -> patterns_of_string
  | Build -> build_of_string
  in
  p env.dawg r

let primitive env op r =
  let o = unary_of op in
  env.operator <- operator_of_uop o;
  unary env o r

let current_primitive env r =
  unary env env.operator.proc r

let binary o l r =
  let l, r = set_of_elem l, set_of_elem r in
  let s = match binary_of o with
  | Union -> StringSet.union l r
  | Inter -> StringSet.inter l r
  | Diff  -> StringSet.diff  l r
  in
  to_list s

let lookup env v = []

let rec eval env t = match t with
  | Node(N_Root, _, [x])                   -> eval env x
  | Node(N_prim, [A_uop, o; A_rack, r], _) -> primitive env o r
  | Node(N_var, [A_name, v], _)            -> lookup env v
  | Node(N_expr, [A_bop, o], [l; r])       -> binary o (eval env l) (eval env r)
  | Node(N_intr, [A_rack, r], [])          -> current_primitive env r
  | _ -> invalid_arg "Input not recognized"
;;

(* parser *)

let parse str =
  Aurochs.read ~grammar:(`Program Vx.program) ~text:(`String str)
