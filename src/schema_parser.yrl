Nonterminals root definition option fields field key_def value attribute_def attributes enums enum_def unions union_def atoms atom struct_def struct_fields.
Terminals  table struct enum union namespace root_type include attribute file_identifier file_extension float int bool string '}' '{' '(' ')' '[' ']' ';' ',' ':' '=' quote.
Rootsymbol root.

root -> definition      : {'$1', #{}}.
root -> option          : {#{}, '$1'}.
root -> root definition : add_def('$1', '$2').
root -> root option     : add_opt('$1', '$2').

% options (non-quoted)
option -> namespace string ';' : #{get_name('$1') => get_value_atom('$2')}.
option -> root_type string ';' : #{get_name('$1') => get_value_atom('$2')}.

% options (quoted)
option -> include quote string quote ';'         : #{get_name('$1') => get_value_bin('$3')}.
option -> attribute quote string quote ';'       : #{get_name('$1') => get_value_bin('$3')}.
option -> file_identifier quote string quote ';' : #{get_name('$1') => get_value_bin('$3')}.
option -> file_extension quote string quote ';'  : #{get_name('$1') => get_value_bin('$3')}.

% definitions
definition -> table string '{' fields '}'           : #{get_value_atom('$2') => {table, '$4'}}.
definition -> table string '{' '}'                  : #{get_value_atom('$2') => {table, []}}.
definition -> enum string ':' string '{' enums '}'  : #{get_value_atom('$2') => {{enum, get_value_atom('$4')}, '$6'}}.
definition -> union string '{' unions '}'           : #{get_value_atom('$2') => {union, '$4'}}.
definition -> struct string '{' struct_fields '}'   : #{get_value_atom('$2') => {struct, '$4'}}.

% enums
enums -> enum_def             : [ '$1' ].
enums -> enum_def ',' enums   : [ '$1' | '$3'].
enums -> enum_def ','         : [ '$1' ].

enum_def -> string                : get_value_atom('$1').
enum_def -> string '=' int        : {get_value_atom('$1'), '$3'}.
enum_def -> string '=' atom       : {get_value_atom('$1'), '$3'}.

% unions
unions -> union_def             : [ '$1' ].
unions -> union_def ',' unions  : [ '$1' | '$3'].
unions -> union_def ','         : [ '$1' ].

union_def -> string : get_value_atom('$1').

% tables
fields -> field ';'         : [ '$1' ].
fields -> field ';' fields  : [ '$1' | '$3' ].

field -> key_def                    : '$1'.
field -> key_def '(' attributes ')' : '$1'.

key_def -> string ':' string              : {get_value_atom('$1'), get_value_atom('$3')}.
key_def -> string ':' '[' string ']'      : {get_value_atom('$1'), {vector, get_value_atom('$4')}}.
key_def -> string ':' string '=' value    : {get_value_atom('$1'), {get_value_atom('$3'), '$5'}}.

attributes -> attributes ',' attribute_def. %ignore
attributes -> attribute_def.                %ignore
attribute_def -> string ':' value.          %ignore
attribute_def -> string.                    %ignore

value -> int      : get_value('$1').
value -> float    : get_value('$1').
value -> bool     : get_value('$1').
value -> string   : get_value_bin('$1').

% enums + unions
atoms -> atom             : [ '$1' ].
atoms -> atom ',' atoms   : [ '$1' | '$3'].
atoms -> atom ','         : [ '$1' ].

atom -> string : get_value_atom('$1').

% struct fields
struct_fields -> field ';'             : [ '$1' ].
struct_fields -> field ';' struct_fields : [ '$1' | '$3' ].

Erlang code.

get_value_atom({_Token, _Line, Value}) -> list_to_atom(Value).
get_value_bin({_Token, _Line, Value})  -> list_to_binary(Value).
get_value({_Token, _Line, Value})      -> Value.

get_name({Token, _Line, _Value})  -> Token;
get_name({Token, _Line})          -> Token.

add_def({Defs, Opts}, Def) -> {maps:merge(Defs, Def), Opts}.
add_opt({Defs, Opts}, Opt) -> {Defs, maps:merge(Opts, Opt)}.