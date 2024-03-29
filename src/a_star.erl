%%%-------------------------------------------------------------------
%%% @doc
%%% a* path finding algorithm
%%% @end
%%%-------------------------------------------------------------------
-module(a_star).
%% API
-export([find/3, find/4]).
%% export type
-export_type([point/0, walkable/0]).
%% type
-type point() :: {non_neg_integer(), non_neg_integer()}.
-type walkable() :: {Module :: module(), Function :: atom()} | fun((Id :: non_neg_integer(), Point :: point()) -> boolean()).
%% coordinate directions
-define(DIRECTIONS, [1, 2, 3, 4, 5, 6, 7, 8]).
%% state
-record(state, {
    open_trees = {0, nil} :: gb_trees:tree(),
    close_sets = {0, nil} :: gb_sets:set(),
    parents_trees = {0, nil} :: gb_trees:tree(),
    dst = {0, 0} :: point(),
    walkable = fun(_, _) -> true end :: walkable()
}).
%% coordinate
-record(coordinate, {
    point = {0, 0} :: point(),
    id = 0 :: non_neg_integer(),
    g = 0 :: non_neg_integer(),
    h = 0 :: non_neg_integer(),
    f = 0 :: non_neg_integer()
}).
%%%===================================================================
%%% API
%%%===================================================================
%% @doc find
-spec find(Id :: non_neg_integer(), Start :: point(), End :: point()) -> Path :: [point()].
find(Id, Start, End) ->
    find(Id, Start, End, fun(_, _) -> true end).

%% @doc find
-spec find(Id :: non_neg_integer(), Start :: point(), End :: point(), Callback :: {Module :: module(), Function :: atom()} | fun((Id :: non_neg_integer(), Point :: point()) -> boolean())) -> Path :: [point()].
find(Id, Start, End, Walkable) ->
    State = #state{
        open_trees = gb_trees:empty(),
        close_sets = gb_sets:empty(),
        parents_trees = gb_trees:empty(),
        dst = End,
        walkable = Walkable
    },
    StartPoint = #coordinate{id = Id, point = Start},
    OpenTrees = gb_trees:enter(Start, {0, 0, 0}, State#state.open_trees),
    NewState = State#state{open_trees = OpenTrees},
    find_next_point(StartPoint, NewState).

%%%===================================================================
%%% Internal functions
%%%===================================================================
%% loop find backtrace
find_next_point(#coordinate{point = Point}, #state{dst = Point} = State) ->
    construct_path(Point, State#state.parents_trees, [Point]);
find_next_point(#coordinate{point = Start} = Coordinate, State) ->
    %% open to close
    OpenTrees = gb_trees:delete(Start, State#state.open_trees),
    CloseSets = gb_sets:add(Start, State#state.close_sets),
    NewState = State#state{open_trees = OpenTrees, close_sets = CloseSets},
    %% add around point to open trees
    AroundPoints = find_around_points(?DIRECTIONS, Coordinate, NewState, []),
    NewestState = add_open_trees(AroundPoints, Start, NewState),
    case find_min_f_point(gb_trees:iterator(NewestState#state.open_trees), -1, none) of
        none ->
            [];
        NextPoint ->
            find_next_point(NextPoint, NewestState)
    end.

%% f coefficient
find_min_f_point(Iterator, F, Coordinate) ->
    case gb_trees:next(Iterator) of
        {Point, {NextG, NextH, NextF}, NewIterator} ->
            case NextF < F orelse F =:= -1 of
                true ->
                    NewCoordinate = #coordinate{point = Point, g = NextG, h = NextH, f = NextF},
                    find_min_f_point(NewIterator, NextF, NewCoordinate);
                false ->
                    find_min_f_point(NewIterator, F, Coordinate)
            end;
        none ->
            Coordinate
    end.

%% find around points
find_around_points([], _, _, List) ->
    List;
find_around_points([Direction | T], Parent = #coordinate{point = {X, Y}, id = Id}, State = #state{close_sets = CloseSets, walkable = Walkable}, List) ->
    Point = coordinate(Direction, X, Y),
    case walkable(Walkable, Id, Point) of
        true ->
            case gb_sets:is_element(Point, CloseSets) of
                false ->
                    Coordinate = make_coordinate(Point, Parent, State#state.dst),
                    find_around_points(T, Parent, State, [Coordinate | List]);
                true ->
                    find_around_points(T, Parent, State, List)
            end;
        false ->
            find_around_points(T, Parent, State, List)
    end.

make_coordinate({CurrentX, CurrentY}, #coordinate{g = G, point =  {ParentX, ParentY}, id = Id}, {DstX, DstY}) ->
    case (CurrentX =:= ParentX) orelse (CurrentY =:= ParentY) of
        true ->
            AddG = 10;
        false ->
            AddG = 14
    end,
    CurH = (erlang:abs(CurrentX - DstX) + erlang:abs(CurrentY - DstY)) * 10,
    #coordinate{point = {CurrentX, CurrentY}, id = Id, g = G + AddG, h = CurH, f = G + AddG + CurH}.

%% add open tree
add_open_trees([], _ParentXY, State) ->
    State;
add_open_trees([Point | Tail], ParentPoint, State) ->
    case gb_trees:lookup(Point#coordinate.point, State#state.open_trees) of
        {_XY, {G, _H, _F}} ->
            case Point#coordinate.g < G of
                true ->
                    State1 = do_add_open_trees(Point, ParentPoint, State),
                    add_open_trees(Tail, ParentPoint, State1);
                false ->
                    add_open_trees(Tail, ParentPoint, State)
            end;
        none ->
            State1 = do_add_open_trees(Point, ParentPoint, State),
            add_open_trees(Tail, ParentPoint, State1)
    end.

do_add_open_trees(Coordinate, ParentPoint, State) ->
    #coordinate{point = Point, g = G, h = H, f = F} = Coordinate,
    NewOpenTrees = gb_trees:enter(Point, {G, H, F}, State#state.open_trees),
    NewParentsTrees = gb_trees:enter(Point, ParentPoint, State#state.parents_trees),
    State#state{open_trees = NewOpenTrees, parents_trees = NewParentsTrees}.

%% coordinate neighbors
coordinate(1, X, Y) ->
    {X, Y - 1};
coordinate(2, X, Y) ->
    {X + 1, Y - 1};
coordinate(3, X, Y) ->
    {X + 1, Y};
coordinate(4, X, Y) ->
    {X + 1, Y + 1};
coordinate(5, X, Y) ->
    {X, Y + 1};
coordinate(6, X, Y) ->
    {X - 1, Y + 1};
coordinate(7, X, Y) ->
    {X - 1, Y};
coordinate(8, X, Y) ->
    {X - 1, Y - 1}.

%% construct connect path
construct_path(Point, ParentsTrees, List) ->
    case gb_trees:lookup(Point, ParentsTrees) of
        {value, NewPoint} ->
            construct_path(NewPoint, ParentsTrees, [NewPoint | List]);
        none ->
            List
    end.

%% walkable set
walkable(_, _, {X, Y}) when X =< 0 orelse Y =< 0 ->
    false;
walkable({Module, Function}, Id, Point) ->
    Module:Function(Id, Point);
walkable(Function, Id, Point) ->
    Function(Id, Point).
