export  Update,
        addcolumnupdate!,
        update

"""
```
Update( name::Union{Var, AbstractString} )
```
This mutable struct represents a `UPDATE` SQL statement where `name` is the name of the affected table.
"""
mutable struct Update <: SQLStatement
    name::Var
    columns::Vector{Var}
    values::Vector
    wherec::SQLCondition
    returning::Vector{String}

    Update( name::SVar ) = new( name |> Var, Var[], Any[], nocond, String[] )
end

function Base.show( io::IO, up::Update )
    isempty(up.columns) && return
    print( io, "UPDATE ", up.name, "\n    SET ", join( string.( up.columns, " = ", processentry.(up.values) ), ", " ) )
    isempty(up.wherec) || print( io, "\n    WHERE ", up.wherec )
    isempty(up.returning) || print( io, "\n    RETURNING ", join( up.returning, ", " ) )
end


"""
```
addcolumnupdate!( colname::Union{Var, AbstractString}, val )
```
This function permits the user to add a command that the column `colname` with the value `val` to a `Update` struct.

The output of this function is a function that takes a `Update` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> addcolumnupdate!( "var1", "val1" ) |> addcolumnupdate!( "var2", "val2" )
```
sets the commands to update column `var1` to `val1` and `var2` to `val2` in the `Update` struct.
"""
addcolumnupdate!( colname::SVar, val ) = up::Update -> begin
    push!( up.columns, colname |> Var )
    push!( up.values, val )
    up
end


"""
```
update( conn::Conn, df::Bool=true )
```
This function permits the user to execute the SQL equivalent of a `Update` struct on the database that `conn` connects to. The flag `df` determines the format of the output (`DataFrame` or `NamedTuple`) if the statement will return an output.

The output of this function is a function that takes a `Update` as argument and returns the result of the executed SQL statement.

Example:
```
sq |> update(conn)
```
"""
update( conn::Conn, df::Bool=true ) = up::Update -> begin
    res = LibPQ.execute( conn, string( up, ";" ) )
    isempty(up.returning) && return res
    res |> makeunique! |> (df ? DataFrame : columntable)
end
