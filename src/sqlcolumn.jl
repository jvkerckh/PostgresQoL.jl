struct SQLString
    str::String
end

Base.show( io::IO, sstr::SQLString ) = print( io, "'$(sstr.str)'" )


mutable struct SQLColumn
    tablename::String
    name::String
end

SQLColumn( name::AbstractString ) = SQLColumn( "", name )

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
