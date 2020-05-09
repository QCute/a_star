# a_star
* an a* path finding algorithm

# quick start
* Add to rebar.config
```
{deps, [
  ...
  {a_star, {git, "https://github.com/QCute/a_star.git", {branch, "master"}}}
]}.
```

* find path
1. find unblock path

```
a_star:find(1, {1, 1}, {10, 10}).
```

2. find with block path

```
a_star:find(1, {1, 1}, {10, 10}, {map, walkable}).
%% or
a_star:find(1, {1, 1}, {10, 10}, fun map:walkable/2}).
```
