export  DropTable,
        addtables!,
        droptable

"""
```
DropTable( names::Vector{Var} )
DropTable( names::Vector{T} ) where T <: AbstractString
DropTable( names::Union{Var, AbstractString}... )
```
This mutable struct represents a `DROP TABLE` SQL statement where `names` are the names of the tables to drop.
"""
mutable struct DropTable <: SQLStatement
    names::Vector{Var}
end

DropTable( names::Vector{T} ) where T <: AbstractString = Var.(names) |> DropTable
DropTable( names::SVar... ) = Var.( names |> collect ) |> DropTable

function Base.show( io::IO, dt::DropTable )
    isempty(dt.names) && return
    print( io, "DROP TABLE ", join( unique(dt.names), ", " ) )
end


"""
```
addtables!( names::Vector{Var} )
addtables!( names::Vector{T} ) where T <: AbstractString
addtables!( names::Union{Var, AbstractString}... )
```
This function permits the user to add a command to add the tables in `names` to the list of tables to drop of a `DropTable` struct.

The output of this function is a function that takes a `DropTable` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> addtables!( "table1", "table2" )
```
adds two tables to drop to the `DropTable` struct: `table1` and `table2`.
"""
addtables!( names::Vector{Var} ) = dt::DropTable -> begin
    append!( dt.names, names )
    dt
end
addtables!( names::Vector{T} ) where T <: AbstractString = Var.(names) |> addtables!
addtables!( names::SVar... ) = Var.( names |> collect ) |> addtables!


function sanitise!( dt::DropTable, conn::Conn, muteerror::Bool )
    unique!(dt.names)
    muteerror || return

    dbtables = Var.( conn |> gettables )
    filter!( name -> name ∈ dbtables, dt.names )
end


"""
```
droptable( conn::Conn; muteerror::Bool=true )
```
This function permits the user to execute the SQL equivalent of a `DropTable` struct on the database that `conn` connects to. If the flag `muteerror` is `true`, the `DropTable` struct gets sanitised so only existing tables

The output of this function is a function that takes a `DropTable` as argument and returns the result of the executed SQL statement.

Example:
```
sq |> droptable(conn)
```
"""
droptable( conn::Conn; muteerror::Bool=true ) = dt::DropTable -> begin
    sanitise!( dt, conn, muteerror )
    LibPQ.execute( conn, string( dt, ";" ) )
end
