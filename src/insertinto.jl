export  InsertInto,
        setcolumns!,
        addentries!,
        insertinto


"""
```
InsertInto( name::Union{Var, AbstractString}, columns::Vector{Var}=Var[] )
InsertInto( name::Union{Var, AbstractString}, columns::Vector{T}=String[] ) where T <: AbstractString
InsertInto( name::Union{Var, AbstractString}, columns::Union{Var, AbstractString}... )
```
This mutable struct represents a `INSERT INTO` SQL statement where `name` is the name of the affected table, and `columns` are the names of the columns where values will be inserted.
"""
mutable struct InsertInto <: SQLStatement
    name::Var
    columns::Vector{Var}
    entries::Vector{Vector}
    returning::Vector{String}

    InsertInto( name::SVar, columns::Vector{Var}=Var[] ) = new( name, columns, Vector[], String[] )
end

InsertInto( name::SVar, columns::Vector{T}=String[] ) where T <: AbstractString = InsertInto( name, Var.(columns) )
InsertInto( name::SVar, columns::SVar... ) = InsertInto( name, map( cname -> cname isa Var ? cname : Var(cname), columns |> collect ) )

function Base.show( io::IO, ini::InsertInto )
    isempty(ini.entries) && return
    print( io, "INSERT INTO ", ini.name, "" )
    isempty(ini.columns) || print( io, " (", join( ini.columns, ", " ), ")" )
    print( io, "\n    VALUES " )
    vstr = map(ini.entries) do entry
        string( "(", join( processentry.(entry), ", " ), ")" )
    end
    print( io, join( vstr, ", " ) )
    isempty(ini.returning) || print( io, "\n    RETURNING ", join( ini.returning, ", " ) )
end


"""
```
setcolumns!( columns::Vector{Var} )
setcolumns!( columns::Vector{T} ) where T <: AbstractString
setcolumns!( columns::Union{Var, AbstractString}... )
```
This function permits the user to add a command that sets the affected columns to `columns` of a `InsertInto` struct.

The output of this function is a function that takes a `InsertInto` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Example:
```
sq |> setcolumns!( "var1", "var2" )
```
sets the affected columns of the `InsertInto` struct to `var1` and `var2`.
"""
setcolumns!( columns::Vector{Var} ) = ini::InsertInto -> begin
    ini.columns = columns
    ini
end

setcolumns!( columns::Vector{T} ) where T <: AbstractString = Var.(columns) |> setcolumns!
setcolumns!( columns::SVar... ) = Var.( columns |> collect ) |> setcolumns!


"""
```
addentries!( entries::Vector... )
```
This function permits the user to add a command that adds the entries in `entries` to a `InsertInto` struct.

The output of this function is a function that takes a `InsertInto` as argument and returns the updated argument, such that Julia's function chaining syntax can be used.

Important: this function does **NOT** check of the number of elements in each entry matches the number of columns defined in the `InsertInto` struct.

Example:
```
sq |> addentries!( [ "val1", "val2" ] ) |> addentries!( [ "val3", "val4" ], [ "val5", "val6" ] )
```
adds 3 entries to the `InsertInto` struct.
"""
addentries!( entries::Vector... ) = ini::InsertInto -> begin
    append!( ini.entries, entries )
    ini
end


function verify( ini::InsertInto )
    isempty(ini.entries) && return Int[]
    nvals = length(isempty(ini.columns) ? ini.entries[1] : ini.columns)
    findall( nvals .!= length.(ini.entries) )
end


"""
```
insertinto( conn::Conn, df::Bool=true )
```
This function permits the user to execute the SQL equivalent of a `InsertInto` struct on the database that `conn` connects to. The flag `df` determines the format of the output (`DataFrame` or `NamedTuple`) if the statement will return an output.

The output of this function is a function that takes a `InsertInto` as argument and returns the result of the executed SQL statement.

Example:
```
sq |> insertinto(conn)
```
"""
insertinto( conn::Conn, df::Bool=true ) = ini::InsertInto -> begin
    badinds, ncols = verify(ini)

    if !isempty(badinds)
        @warn "$(length(badinds)) entries have the wrong number of fields (must be $ncols), first one at $(badinds[1])."
        return
    end

    res = LibPQ.execute( conn, string( ini, ";" ) )
    isempty(ini.returning) && return res
    res |> makeunique! |> (df ? DataFrame : columntable)
end
