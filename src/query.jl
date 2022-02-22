abstract type SQLQuery <: SQLStatement end


export  Select,
        addqueryfield!,
        setwhereclause!,
        setgroupby!,
        sethavingclause!,
        select


"""
```
Select(
    name::Union{Var, AbstractString, JoinTable}="",
    alias::Union{Var, AbstractString}="";
    distinct::Bool=false )
Select(
    sq::Select,
    alias::Union{Var, AbstractString};
    distinct::Bool=false )
```
This mutable struct represents a `SELECT` SQL statement where `name` is the table to select from, `alias` is the alias for the table, if any is given, and `distinct` determines whether the `DISTINCT` flag is set, that is, identical records are suppressed in the output.

With the second version of the constructor that takes a `Select` as first argument, `alias` is an obligatory argument.
"""
mutable struct Select <: SQLQuery
    isdistinct::Bool
    name::String
    alias::String
    columns::Vector{String}
    aliases::Vector{Var}
    wherec::SQLCondition
    groupby::Vector{Var}
    having::SQLCondition
    orderby::Vector{Var}
    asc::Vector{Bool}
    nulllast::Vector{Bool}
    limit::Int
    offset::Int

    Select( name::SVar="", alias::SVar=""; distinct::Bool=false ) = new( distinct, name, alias |> string, String[], Var[], nocond, Var[], nocond, String[], Bool[], Bool[], -1, 0 )
end

Select( jc::JoinTable, alias::SVar=""; distinct::Bool=false ) = Select( "($jc)", alias, distinct=distinct )
Select( sq::Select, alias::SVar; distinct::Bool=false ) = Select( "($sq)", alias, distinct=distinct )

function Base.show( io::IO, sq::Select )
    isempty(sq.columns) && return
    print( io, "SELECT " )
    sq.isdistinct && print( io, "DISTINCT " )
    colstr = map( eachindex(sq.columns) ) do ii
        isempty(sq.aliases[ii]) && return string(sq.columns[ii])
        "$(sq.columns[ii]) AS $(sq.aliases[ii])"
    end
    print( io, join( colstr, ", " ) )

    if !isempty(sq.name)
        print( io, "\n    FROM $(sq.name)" )
        isempty(sq.alias) || print( io, " AS \"$(sq.alias)\"" )
    end

    isempty(sq.wherec) || print( io, "\n    WHERE $(sq.wherec)" )
    isempty(sq.groupby) || print( io, "\n    GROUP BY $(join( sq.groupby, ", " ))" )
    isempty(sq.having) || print( io, "\n    HAVING $(sq.having)" )

    if !isempty(sq.orderby)
        print( io, "\n    ORDER BY " )
        ostr = map( eachindex(sq.orderby) ) do ii
            string( sq.orderby[ii], ' ', sq.asc[ii] ? "ASC" : "DESC", " NULLS ", sq.nulllast[ii] ? "LAST" : "FIRST" )
        end
        print( io, join( ostr, ", " ) )
    end
    
    if (sq.limit >= 0) || (sq.offset > 0)
        print( io, "\n   " )
        sq.limit < 0 || print( io, " LIMIT ", sq.limit )
        sq.offset > 0 && print( io, " OFFSET ", sq.offset )
    end
end


"""
```
addqueryfield!(
    column::SVar,
    alias::SVar="" )
```
This function permits the user to add a command that adds the column `column` to the result of a `Struct` struct. This column can have the alias `alias`.

The output of this function is a function that a `Select` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> addqueryfield!( "var1" ) |> addqueryfield!( "var2 + var3", "varcomb" )
```
sets the commands to add the columns `var1` and `var2 + var3`, aliased by `varcomb`, to the output of the `Select` statement.
"""
addqueryfield!( column::SVar, alias::SVar="" ) = sq::Select -> begin
    push!( sq.columns, column |> string )
    push!( sq.aliases, alias |> Var )
    sq
end


"""
```
setwhereclause!( cond::SQLCondition )
```
This function permits the user to add a command that sets the `WHERE` clause of a `Update`, `DeleteFrom`, or `Select` struct to `cond`.

The output of this function is a function that takes an argument of the aforementioned types and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setwhereclause!( cond )
```
sets the `WHERE` clause of `sq` to `cond` where `cond` ha sbeen defined previously.
"""
function setwhereclause!( cond::SQLCondition )
    dm::Union{Update, DeleteFrom, Select} -> begin
        dm.wherec = cond
        dm
    end
end


"""
```
setgroupby!( columns::Vector{Var} )
setgroupby!( columns::Vector{T} ) where T <: AbstractString
setgroupby!( columns::Union{Var, AbstractString}... )
```
This function permits the user to add a command that sets the `GROUP BY` clause of a `Select` struct to the columns in `columns`. Note that the function doesn't check if these columns exist in the query result.

The output of this function is a function that takes a `Select` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setgroupby!( "var1", "var2" )
```
sets the command to group the result of the `Select` statement by `var1` and `var2`.
"""
setgroupby!( columns::Vector{Var} ) = sq::Select -> begin
    sq.groupby = columns
    sq
end
setgroupby!( columns::Vector{T} ) where T <: AbstractString = Var.(columns) |> setgroupby!
setgroupby!( columns::SVar... ) = Var.( columns |> collect ) |> setgroupby!


"""
```
sethavingclause!( cond::SQLCondition )
```
This function permits the user to add a command that sets the `HAVING` clause of a `Select` struct to `cond`.

The output of this function is a function that takes a `Select` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> sethavingclause!( cond )
```
sets the command to consider only the fields that satisfy the condition `cond` when grouping the results of the `Select` statement.
"""
sethavingclause!( cond::SQLCondition ) = sq::Select -> begin
    sq.having = cond
    sq
end


"""
```
select( conn::Conn, df::Bool=true )
```
This function permits the user to execute the SQL equivalent of a `Select` struct on the database that `conn` connects to. The flag `df` determines the format of the output (`DataFrame` or `NamedTuple`) if the statement will return an output.

The output of this function is a function that takes a `Struct` as argument and returns the result of the executed SQL statement.

Example:
```
sq |> select(conn)
```
"""
select( conn::Conn, df::Bool=true ) = sq::Select -> begin
    res = LibPQ.execute( conn, string( sq, ";" ) )
    res |> makeunique! |> (df ? DataFrame : columntable)
end
