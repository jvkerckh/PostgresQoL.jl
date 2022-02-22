export  DeleteFrom,
        setreturning!,
        deletefrom


"""
```
DeleteFrom( name::Union{Var, AbstractString}, cond::SQLCondition=nocond )
```
This mutable struct represents a `DELETE FROM` SQL statement where `name` is the name of the affected table, and `cond` is the SQL condition that describes which entries should be deleted from the table.
"""
mutable struct DeleteFrom <: SQLStatement
    name::String
    wherec::SQLCondition
    returning::Vector{String}

    DeleteFrom( name::SVar, cond::SQLCondition=nocond ) = new( name, cond, String[] )
end

function Base.show( io::IO, df::DeleteFrom )
    print( io, "DELETE FROM \"", df.name, "\"" )
    isempty(df.wherec) || print( io, "\n    WHERE ", df.wherec )
    isempty(df.returning) || print( io, "\n    RETURNING ", join( df.returning, ", " ) )
end


"""
```
setreturning!( names::Vector{T} ) where T <: AbstractString
setreturning!( names::Vector{Var} )
setreturning!( names::Union{Var, AbstractString}... )
```
This function permits the user to add a command that sets the `RETURNING` clause of a `InsertInto`, `Update`, or `DeleteFrom` struct to `names`.

The output of this function is a function that takes an argument of the aforementioned types and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setreturning!( "var1", "var2 + var3 AS varcomb" )
```
sets the commands to return `var1` and `var2 + var3`, aliased by `varcomb`.
"""
setreturning!( names::Vector{T} ) where T <: AbstractString =
    dm::Union{InsertInto, Update, DeleteFrom} -> begin
        dm.returning = names |> Vector{String}
        dm
    end
setreturning!( names::Vector{Var} ) = string.(names) |> setreturning!
setreturning!( names::SVar... ) = string.( names |> collect ) |> setreturning!


"""
```
deletefrom( conn::Conn, df::Bool=true )
```
This function permits the user to execute the SQL equivalent of a `DeleteFrom` struct on the database that `conn` connects to. The flag `df` determines the format of the output (`DataFrame` or `NamedTuple`) if the statement will return an output.

The output of this function is a function that takes a `DeleteFrom` as argument and returns the result of the executed SQL statement.

Example:
```
sq |> deletefrom(conn)
```
"""
deletefrom( conn::Conn, df::Bool=true ) = def::DeleteFrom -> begin
    res = LibPQ.execute( conn, string( def, ";" ) )
    isempty(def.returning) && return res
    res |> makeunique! |> (df ? DataFrame : columntable)
end
