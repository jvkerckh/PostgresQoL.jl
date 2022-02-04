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


setunique!( scs::Vector{Var} ) = ct::CreateTable -> begin
    ct.unique = deepcopy(scs)
    ct
end

setunique!( colnames::Vector{T} ) where T <: AbstractString = Var.(colnames) |> setunique!
setunique!( scs::SVar... ) = Var.( scs |> collect ) |> setunique!

setprimary!( scs::Vector{Var} ) = ct::CreateTable -> begin
    ct.primary = deepcopy(scs)
    ct
end

setprimary!( colnames::Vector{T} ) where T <: AbstractString = Var.(colnames) |> setprimary!
setprimary!( scs::SVar... ) = Var.( scs |> collect ) |> setprimary!


function sanitise!( ct::CreateTable )
    ct |> makeunique!
    filter!( var -> var ∈ ct.columns, ct.unique )
    filter!( var -> var ∈ ct.columns, ct.primary )
    ct
end


createtable( conn::Conn ) = ct::CreateTable -> execute( conn, string( ct |> sanitise!, ";" ) )
