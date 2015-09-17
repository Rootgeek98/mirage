(*
 * Copyright (c) 2015 Nicolas Ojeda Bar <n.oje.bar@gmail.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(** Command line parameters *)

(** Description of keys. *)
module Desc : sig

  type 'a t
  (** A complete description *)

  (** To create a description we need:
      @param converter A cmdliner converter.
      @param description The identifier of the runtime description of the key. See {!Functoria_runtime.Desc.t}.
      @param serializer A serialization function output the value as OCaml code.
  *)
  val create :
    serializer:(Format.formatter -> 'a -> unit) ->
    converter:'a Cmdliner.Arg.converter ->
    description:string ->
    'a t

  (** {2 Predefined descriptions} *)

  val string : string t
  val bool : bool t
  val int : int t
  val list : 'a t -> 'a list t
  val option : 'a t -> 'a option t

  (** {2 Accessors} *)

  val serializer : 'a t -> Format.formatter -> 'a -> unit
  val description :  'a t -> string
  val converter : 'a t -> 'a Cmdliner.Arg.converter


end

(** Documentation of keys. *)
module Doc : sig

  type t

  (** Create a documentation. See {!Cmdliner.Arg.info} for details. *)
  val create : ?docs:string -> ?docv:string -> ?doc:string -> string list -> t

  val to_cmdliner : t -> Cmdliner.Arg.info

  (** Emit the documentation as OCaml code. *)
  val emit : Format.formatter -> t -> unit

end

module Set : Functoria_misc.SET
(** A Set of keys. *)


type +'a value
(** Value available at configure time.
    Values have dependencies, which are a set of keys.

    Values are resolved to their content when all
    their dependencies are resolved.
*)

val pure : 'a -> 'a value
(** [pure x] is a value without any dependency. *)

val app : ('a -> 'b) value -> 'a value -> 'b value
(** [app f x] is the value resulting from the application of [f] to [v].
    Its dependencies are the union of the dependencies. *)

val ($) : ('a -> 'b) value -> 'a value -> 'b value
(** [f $ v] is [app f v]. *)

val map : ('a -> 'b) -> 'a value -> 'b value
(** [map f v] is [pure f $ v]. *)

val pipe : 'a value -> ('a -> 'b) -> 'b value
(** [pipe v f] is [map f v]. *)

val if_ : bool value -> 'a -> 'a -> 'a value
(** [if_ v x y] is [pipe v @@ fun b -> if b then x else y]. *)

val with_deps : keys:Set.t -> 'a value -> 'a value
(** [with_deps deps v] is the value [v] with added dependencies. *)

type 'a key
(** Keys are dynamic values that can be used to
    - Set options at configure and runtime on the command line.
    - Switch implementation dynamically, using {!Functoria_dsl.if_impl}.

    Their content is then made available at runtime in the [Bootvar_gen] module.

    Keys are resolved to their content during command line parsing.
*)

val value : 'a key -> 'a value
(** [value k] is the value which depends on [k] and will take its content. *)

type stage = [
  | `Configure
  | `Run
  | `Both
]
(** The stage at which a key is available. This will influence when a key will
    be available on the command line. *)

val create : ?stage:stage -> doc:Doc.t -> default:'a -> string -> 'a Desc.t -> 'a key
(** [create ~doc ~stage ~default name desc] creates a new configuration key with
    docstring [doc], default value [default], name [name] and type descriptor
    [desc]. Default [stage] is [`Both].
    It is an error to use more than one key with the same [name]. *)

val set : 'a key -> 'a -> unit
(** [set key v] sets the value of [key] to [v]. *)

(** {2 Oblivious keys} *)

type t = Set.elt
(** Keys which types has been forgotten. *)

val hidden : 'a key -> t
(** Hide the type of keys. Allows to put them in a set/list. *)

(** {2 Advanced functions} *)

val pp : t Fmt.t
(** [pp fmt k] prints the name of [k]. *)

val pp_deps : 'a value Fmt.t
(** [pp_deps fmt v] prints the name of the dependencies of [v]. *)

val deps : 'a value -> Set.t
(** [deps v] is the dependencies of [v]. *)

val is_resolved : 'a value -> bool
(** [is_reduced v] returns [true] iff all the dependencies of [v] have
    been resolved. *)

val peek : 'a value -> 'a option
(** [peek v] returns [Some x] if [v] has been resolved to [x]
    and [None] otherwise. *)

(** {3 Accessors} *)

val is_runtime : t -> bool
(** [is_runtime k] is true if [k]'s stage is [`Run] or [`Both]. *)

val is_configure : t -> bool
(** [is_configure k] is true if [k]'s stage is [`Configure] or [`Both]. *)

val filter_stage : stage:[< `Both | `Configure | `Run ] -> Set.t -> Set.t
(** [filter_stage ~stage set] filters [set] with the appropriate keys. *)

(** {3 Code emission} *)

val ocaml_name : t -> string
(** [ocaml_name k] is the ocaml name of [k]. *)

val emit_call : t Fmt.t
(** [emit_call fmt k] prints the OCaml code needed to get the value of [k]. *)

val emit : t Fmt.t
(** [emit fmt k] prints the OCaml code needed to define [k]. *)

(** {3 Cmdliner} *)

val term_key : t -> unit Cmdliner.Term.t
(** [term_key k] is a [Cmdliner.Term.t] that, when evaluated, sets the value
    of the the key [k]. *)

val term : ?stage:stage -> Set.t -> unit Cmdliner.Term.t
(** [term l] is a [Cmdliner.Term.t] that, when evaluated, sets the value of the
    the keys in [l]. *)

val term_value : ?stage:stage -> 'a value -> 'a Cmdliner.Term.t
(** [term_value v] is [term @@ deps v] and returns the content of [v]. *)

(**/**)

val get : 'a key -> 'a
val eval : 'a value -> 'a

val module_name : string
(** Name of the generated module containing the keys. *)
