export  JoinTable,
        setnojoincondition!,
        setusingcolumns!,
        setnaturaljoin!,
        setjoincondition!


"""
```
JoinTable(
    name::Union{Var, AbstractString, JoinTable},
    jname::Union{Var, AbstractString},
    jtype::Symbol=:inner;
    alias::Union{Var, AbstractString}="",
    jalias::Union{Var, AbstractString}="" )
```
This mutable struct represents a `JOIN` SQL statement where `name` is the name of the first table, `jname` is the name of the table to join into the first table, `jtype` is the type of join to perform, `alias` is the alias for the first table, and `jalias` is the alias for the second table.

Accepted values for the join type are `:cross`, `:inner`, `:left`, `:right`, and `:full`. Any other value will result in an error being thrown.

An alternative way of creating a `JoinTable` is
```
JoinTable(
    jname::Union{Var, AbstractString},
    jtype::Symbol=:inner;
    jalias::Union{Var, AbstractString}="" )
```
This construct creates a function that takes a `JoinTable` and returns a new `JoinTable` with the argument as the first table in the join. This allows the use of Julia's function chaining syntax.

Example:
```
JoinTable( "table1", "table2" ) |> JoinTable( "table3" )
```
This statement creates a `JoinTable` where `table2` is joined to `table1`, and `table3` is joined to the result of this.
"""
mutable struct JoinTable <: SQLStatement
    name::String
    alias::Var
    jtype::Symbol
    jname::Var
    jalias::Var
    jctype::Symbol
    jcols::Vector{Var}
    jcond::SQLCondition

    function JoinTable( name::Union{SVar, JoinTable}, jname::SVar, jtype::Symbol=:inner; alias::SVar="", jalias::SVar="" )
        jtype ∈ [:cross, :inner, :left, :right, :full] || @error("Unknown join type, must be :cross, :inner, :left, :right, or :full.")
        new( name |> string, alias |> Var, jtype, jname |> Var, jalias |> Var, :none, Var[], nocond )
    end
end

JoinTable( jname::SVar, jtype::Symbol=:inner; jalias::SVar="" ) =
    jc::JoinTable -> begin
        JoinTable( jc |> string, jname, jtype, jalias=jalias )
    end

function Base.show( io::IO, jc::JoinTable )
    print( io, "$(jc.name) " )
    isempty(jc.alias) || print( io, "$(jc.alias) " )
    jc.jctype === :natural && print( io, "NATURAL " )
    print( io, "$(string(jc.jtype) |> uppercase) JOIN $(jc.jname)" )
    isempty(jc.jalias) || print( io, " $(jc.jalias)" )

    if jc.jctype === :using
        print( io, " USING ($(join( string.(jc.jcols), ", " )))" )
    elseif jc.jctype === :on
        print( io, " ON $(jc.jcond)" )
    end
end


"""
```
setnojoincondition!( jc::JoinTable )
```
This function removes the join condition from `jc`, which will result in a table which is the standard Cartesian product between the two tables in `JoinTable`.
"""
function setnojoincondition!( jc::JoinTable )
    jc.jctype = :none
    jc
end


"""
```
setusingcolumns!( columns::Vector{Var} )
setusingcolumns!( columns::Vector{T} ) where T <: AbstractString
setusingcolumns!( columns::SVar... )
```
This function sets the join condition of `jc` to a `USING` join on the columns listed in `columns`. The resulting table suppresses duplicate columns for all the columns that are in the list and are present in both tables.
"""
setusingcolumns!( columns::Vector{Var} ) = jc::JoinTable -> begin
    isempty(columns) && return jc
    jc.jctype = :using
    jc.jcols = columns
    jc
end
setusingcolumns!( columns::Vector{T} ) where T <: AbstractString = Var.(columns) |> setusingcolumns!
setusingcolumns!( columns::SVar... ) = Var.( columns |> collect ) |> setusingcolumns!


"""
```
setnaturaljoin!( jc::JoinTable )
```
This function sets the join condition of `jc` to a `NATURAL` join. The resulting table suppresses duplicate columns for all the columns that have matching names in both tables.
    
This is a shorthand for `USING` with all matching columns listed.
"""
function setnaturaljoin!( jc::JoinTable )
    jc.jctype = :natural
    jc
end


"""
```
setjoincondition!( cond::SQLCondition )
```
This function sets the join condition of `jc` to a generic `ON` clause where the tables are joined on all the pairs of entries that match the condition `cond`.
"""
setjoincondition!( cond::SQLCondition ) = jc::JoinTable -> begin
    if cond === nocond
        jc.jctype = :none
        return jc
    end

    jc.jctype = :on
    jc.jcond = cond
    jc
end
