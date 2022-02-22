export  CreateTable,
        addtablecolumn!,
        setunique!,
        setprimary!,
        createtable

"""
```
CreateTable( tablename::AbstractString )
```
This mutable struct represents a `CREATE TABLE` SQL statement where the name of the table is `tablename`.
"""
mutable struct CreateTable <: SQLStatement
    name::String
    columns::Vector{Var}
    types::Vector{String}
    flags::Vector{Vector{String}}
    unique::Vector{Var}
    primary::Vector{Var}

    CreateTable( tablename::AbstractString ) = new( tablename, Var[], String[], String[], Var[], Var[] )
end

function Base.show( io::IO, ct::CreateTable )
    isempty(ct.columns) && return
    print( io, "CREATE TABLE \"", ct.name, "\" (" )

    for ii in eachindex(ct.columns)
        ii > 1 && print( io, "," )
        print( io, "\n    ", ct.columns[ii], " ", ct.types[ii] )
        isempty(ct.flags[ii]) || print( io, " ", join( ct.flags[ii], " " ) )
    end

    isempty(ct.unique) || print( io, ",\n    UNIQUE (", join( ct.unique, ", " ), ")" )
    isempty(ct.primary) || print( io, ",\n    PRIMARY KEY (", join( ct.primary, ", " ), ")" )
    print( io, "\n)" )
end


"""
```
addtablecolumn!(
    sc::Var,
    valtype::AbstractString,
    flags::Vector{T}=String[] ) 
addtablecolumn!(
    sc::Var,
    valtype::AbstractString,
    flags::Vector{T}=String[] ) 
```
This function permits the user to add a command to add a column with name `sc` of type `valtype` to a `CreateTable` struct. Any additional flags that this column has, such as `NOT NULL`, etc. can be set in `flags`.

The output of this function is a function that takes a `CreateTable` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> addtablecolumn!( "var1", "int" ) |> addtablecolumn!( "var2", "real" )
```
adds two columns to the `CreateTable` struct: a column `var1` of type `int`, and a column `var2` of type `real`.
"""
addtablecolumn!( sc::Var, valtype::AbstractString, flags::Vector{T}=String[] ) where T <: AbstractString = ct::CreateTable -> begin
    push!( ct.columns, sc )
    push!( ct.types, valtype )
    push!( ct.flags, flags )
    ct
end

addtablecolumn!( name::AbstractString, valtype::AbstractString, flags::Vector{T}=String[] ) where T <: AbstractString =
    addtablecolumn!( name |> Var, valtype, flags )


allunique( ct::CreateTable ) = length(ct.columns) == length(unique(ct.columns))


function makeunique!( ct::CreateTable )
    makeunique!( ct.columns )
    ct
end


"""
```
setunique!( scs::Vector{Var} )
setunique!( scs::Vector{T} ) where T <: AbstractString
setunique!( scs::Union{Var, AbstractString}... )
```
This function permits the user to add a command that sets the unique clause to enforce uniqueness on the combination of the variables in `scs` of a `CreateTable` struct.

The output of this function is a function that takes a `CreateTable` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setunique!( "var1", "var2" )
```
sets the uniqueness constraint that all combinations of values of `var1` and `var2` in the table must be unique.
"""
setunique!( scs::Vector{Var} ) = ct::CreateTable -> begin
    ct.unique = deepcopy(scs)
    ct
end

setunique!( scs::Vector{T} ) where T <: AbstractString = Var.(scs) |> setunique!
setunique!( scs::SVar... ) = Var.( scs |> collect ) |> setunique!


"""
```
setprimary!( scs::Vector{Var} )
setprimary!( scs::Vector{T} ) where T <: AbstractString
setprimary!( scs::Union{Var, AbstractString}... )
```
This function permits the user to add a command that sets the primary key clause to the variables in `scs` in a `CreateTable` struct. A primary key cluase is like the unique clause, with the added constraint that none of the variables can have a null value.

The output of this function is a function that takes a `CreateTable` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setprimary!( "var1", "var2" )
```
sets the primary key clause to the combination of `var1` and `var2`.
"""
setprimary!( scs::Vector{Var} ) = ct::CreateTable -> begin
    ct.primary = deepcopy(scs)
    ct
end

setprimary!( colnames::Vector{T} ) where T <: AbstractString = Var.(colnames) |> setprimary!
setprimary!( scs::SVar... ) = Var.( scs |> collect ) |> setprimary!


function sanitise!( ct::CreateTable )
    ct |> makeunique!
    filter!( var -> var ∈ ct.columns, ct.unique ) |> unique!
    filter!( var -> var ∈ ct.columns, ct.primary ) |> unique!
    ct
end


"""
```
createtable( conn::Conn )
```
This function permits the user to execute the SQL equivalent of a `CreateTable` struct on the database that `conn` connects to.

The output of this function is a function that takes a `CreateTable` as argument and returns the result of the executed SQL statement.

Example:
```
sq |> createtable(conn)
```
"""
createtable( conn::Conn ) = ct::CreateTable -> LibPQ.execute( conn, string( ct |> sanitise!, ";" ) )
