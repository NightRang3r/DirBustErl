-module(dirbusterl_visited_urls).
-export([start_link/0, book_visit/2, stop/1]).
-export([init/1, handle_call/3, terminate/2]). %% gen_server callbacks
-behavior(gen_server).


%% External API

start_link() -> gen_server:start_link(?MODULE, [], []).

book_visit(Pid, URL) -> gen_server:call(Pid, {book, URL}).

stop(Pid) -> gen_server:call(Pid, stop).


%% Callbacks for gen_server

init([]) -> {ok, gb_trees:empty()}.

handle_call(stop, _From, Tree) -> {stop, normal, ok, Tree};
handle_call({book, URL}, _From, Tree) ->
	Parts = binary:split(binary:replace(list_to_binary(URL), <<"://">>, <<"/">>), <<"/">>, [global]),
	case check_url(Parts, {true, Tree}) of
		already_visited -> {reply, false, Tree};
		{updated, NewTree} -> {reply, true, NewTree}
	end.

terminate(_, _) -> ok.


%% Internal functions

check_url([], {true, _}) -> already_visited;
check_url([], {false, _}) -> update_leaf;
check_url([Part | Rest], {_, Parent}) ->
	case gb_trees:lookup(Part, Parent) of
		none ->
			SubTree = lists:foldr(fun (E, A) -> {false, gb_trees:insert(E, A, gb_trees:empty())} end,
				{true, gb_trees:empty()}, Rest),
			{updated, gb_trees:insert(Part, SubTree, Parent)};
		{value, {NodeStatus, NodeTree} = Child} ->
			case check_url(Rest, Child) of
				already_visited -> already_visited;
				update_leaf -> {updated, gb_trees:update(Part, {true, NodeTree}, Parent)};
				{updated, NewTree} -> {updated, gb_trees:update(Part, {NodeStatus, NewTree}, Parent)}
			end
	end.
