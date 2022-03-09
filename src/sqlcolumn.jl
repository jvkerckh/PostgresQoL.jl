export  SQLString,
        SQLColumn, Var

"""
```
SQLString( x )
```
This is a non-mutable struct that represents an SQL string constant. Any non-string entries are first processed to a string, then cast as a `SQLString` object.
"""
struct SQLString
    str::String

    SQLString( x::AbstractString ) = new(x)
end

SQLString( sqls::SQLString ) = sqls
SQLString( x ) = x |> processentry |> SQLString

Base.show( io::IO, sstr::SQLString ) = print( io, "'$(sstr.str)'" )


"""
```
SQLColumn(
    tablename::String,
    name::String )
SQLColumn( name::AbstractString )
```
This is a non-mutable struct that represents a column with a given `name` belonging to a specific table with name `tablename`, or the current table with the second calling method. It can also represent the name of an alias in the same manner.
"""
struct SQLColumn
    tablename::String
    name::String
end

SQLColumn( name::AbstractString ) = SQLColumn( "", name )

"""
`Var` is a shorthand for `SQLColumn`, the Julia type that represents a column or alias belonging to a specific database table (or the current one).
"""
const Var = SQLColumn
const SVar = Union{Var, AbstractString}
Var( sc::Var ) = sc

function Base.show( io::IO, sc::Var )
    isempty(sc.tablename) || print( io, "\"$(sc.tablename)\".")
    print( io, "\"$(sc.name)\"" )
end

Base.isempty( sc::Var ) = isempty(sc.name)

# Both functions are necessary for unique( scs::Vector{SQLColumn} ) to work.
Base.:(==)( sc1::Var, sc2::Var ) = sc1.name == sc2.name
Base.hash( sc::Var ) = hash("$(sc.tablename).$(sc.name)")


function makeunique!( v::Vector{SQLColumn} )
    vunique = unique(v)
    length(vunique) == length(v) && return v

    for el in vunique
        inds = findall(v .== Ref(el))
        
        for ii in 1:(length(inds) - 1)
            v[inds[ii+1]].name = string( v[inds[ii+1]].name, '_', ii )
        end
    end

    v
end
