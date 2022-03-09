export  addorderby!,
        clearlimit!,
        setlimit!,
        clearoffset!,
        setoffset!


struct CompoundQuery <: SQLQuery
    larg::String
    rarg::String
    cop::Symbol
    isall::Bool
    orderby::Vector{String}
    asc::Vector{Bool}
    nulllast::Vector{Bool}
    limit::Int
    offset::Int

    CompoundQuery( larg::AbstractString, rarg::AbstractString, cop::Symbol, isall::Bool ) = new( larg, rarg, cop, isall, Var[], Bool[], Bool[], -1, 0 )
end

function Base.show( io::IO, cq::CompoundQuery )
    print( io, "(", cq.larg, ") ", uppercase(cq.cop |> string), " " )
    cq.isall && print( io, "ALL " )
    print( io, "(", cq.rarg, ")" )

    if !isempty(cq.orderby)
        print( io, "\n    ORDER BY " )
        ostr = map( eachindex(cq.orderby) ) do ii
            print( io, cq.orderby[ii], ' ', cq.asc[ii] ? "ASC" : "DESC", " NULLS ", cq.nulllast[ii] ? "LAST" : "FIRST" )
        end
        print( io, join( ostr, ", " ) )
    end

    if (cq.limit >= 0) || (cq.offset > 0)
        print( io, "\n   " )
        cq.limit < 0 || print( io, " LIMIT ", cq.limit )
        cq.offset > 0 && print( io, " OFFSET ", cq.offset )
    end
end


for cop in [:union, :intersect, :except]
    Core.eval( @__MODULE__, "export query$cop" |> Meta.parse )
    Core.eval( @__MODULE__, """\"\"\"
    ```
    query$cop(
        larg::Union{Select, CompoundQuery},
        rarg::Union{Select, CompoundQuery},
        isall::Bool=false )
    ```
    This function creates a `CompoundQuery` object consisting of the SQL operator `$(lowercase( cop |> string ))` applied to `larg` and `rarg` as left and right arguments respectively. The argument `isall` determines whether the flag `ALL` will be set, that is, whether duplicate rows will be kept or not.

    Note that this function does not check of the results of the two queries are compatible.
    \"\"\"
    query$cop( larg::Union{Select, CompoundQuery}, rarg::Union{Select, CompoundQuery}, isall::Bool=false ) = CompoundQuery( larg |> string, rarg |> string, :$cop, isall )""" |> Meta.parse )
end


"""
```
addorderby!(
    column::SVar;
    asc::Bool=true,
    nullorder::Symbol=:default )
```
This function permits the user to add a command that adds the column `column` to the `ORDER BY` clause of a `Select` or `CompoundQuery` struct. The argument `asc` controls the sorting order of the column, ascending or descending, and the argument `nullorder` controls where to place `NULL` entries in the column. This argument can take only the values `:first`, `:last`, or `:default`.

The output of this function is a function that takes an argument of type `Select` or `CompoundQuery` and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> addorderby!( "var2" ) |> addorderby!( "var1", asc=false )
```
sets the command to order the result of `sq` first by `var2` in ascending order, then by `var2` in descending order.
"""
function addorderby!( column::SVar; asc::Bool=true, nullorder::Symbol=:default )
    sq::SQLQuery -> begin
        if nullorder ∉ [:first, :last, :default]
            @warn "Unknown nullorder, must be one of :first, :last, or :default"
            return sq
        end

        push!( sq.orderby, Var(column) )
        push!( sq.asc, asc )
        push!( sq.nulllast, nullorder === :default ? asc : nullorder === :first )
        sq
    end
end


"""
```
clearlimit!( sq::Union{Select, CompoundQuery} )
```
This function clears the `LIMIT` clause of the query `sq` and returns the updated query.
"""
function clearlimit!( sq::SQLQuery )
    sq.limit = -1
    sq
end


"""
```
setlimit!( limit::Integer )
```
This function permits the user to add a command that sets the `LIMIT` clause of a `Select` or `CompoundQuery` struct to `limit`.

The output of this function is a function that takes an argument of type `Select` or `CompoundQuery` and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setlimit!( 100 )
```
sets the `LIMIT` clause of `sq` to 100.
"""
setlimit!( limit::Integer ) = sq::SQLQuery -> begin
    limit < 0 && return clearlimit!(sq)
    sq.limit = limit |> Int
    sq
end


"""
```
clearoffset!( sq::Union{Select, CompoundQuery} )
```
This function clears the `OFFSET` clause of the query `sq` and returns the updated query.
"""
function clearoffset!( sq::SQLQuery )
    sq.offset = 0
    sq
end


"""
```
setoffset!( offset::Integer )
```
This function permits the user to add a command that sets the `OFFSET` clause of a `Select` or `CompoundQuery` struct to `offset`.

The output of this function is a function that takes an argument of type `Select` or `CompoundQuery` and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setoffset!( 10 )
```
sets the `OFFSET` clause of `sq` to 10.
"""
setoffset!( offset::Integer ) = sq::SQLQuery -> begin
    offset > 0 || return clearoffset!(sq)
    sq.offset = offset |> Int
    sq
end


"""
```
compoundquery( conn::Conn, df::Bool=true )
```
This function permits the user to execute the SQL equivalent of a `CompoundQuery` struct on the database that `conn` connects to. The flag `df` determines the format of the output (`DataFrame` or `NamedTuple`) if the statement will return an output.

The output of this function is a function that takes a `Struct` as argument and returns the result of the executed SQL statement.

Example:
```
sq |> compoundquery(conn)
```
"""
compoundquery( conn::Conn, df::Bool=true ) = cq::CompoundQuery -> begin
    res = execute( conn, string( cq, ";" ) )
    res |> makeunique! |> (df ? DataFrame : columntable)
end
