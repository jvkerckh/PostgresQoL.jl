mutable struct InsertInto <: SQLStatement
    name::String
    columns::Vector{Var}
    entries::Vector{Vector}
    returning::Vector{String}

    InsertInto( name::AbstractString, columns::Vector{Var}=Var[] ) = new( name, columns, Vector[], String[] )
end

InsertInto( name::AbstractString, columns::Vector{T}=String[] ) where T <: AbstractString = InsertInto( name, Var.(columns) )
InsertInto( name::AbstractString, columns::SVar... ) = InsertInto( name, map( cname -> cname isa Var ? cname : Var(cname), columns |> collect ) )

function Base.show( io::IO, ini::InsertInto )
    isempty(ini.entries) && return
    print( io, "INSERT INTO \"", ini.name, "\"" )
    isempty(ini.columns) || print( io, " (", join( ini.columns, ", " ), ")" )
    print( io, "\n    VALUES " )
    vstr = map(ini.entries) do entry
        string( "(", join( processentry.(entry), ", " ), ")" )
    end
    print( io, join( vstr, ", " ) )
    isempty(ini.returning) || print( io, "\n    RETURNING ", join( ini.returning, ", " ) )
end


setcolumns!( columns::Vector{Var} ) = ini::InsertInto -> begin
    ini.columns = columns
    ini
end

setcolumns!( columns::Vector{T} ) where T <: AbstractString = Var.(columns) |> setcolumns!
setcolumns!( columns::SVar... ) = Var.( columns |> collect ) |> setcolumns!


addentries!( entries::Vector... ) = ini::InsertInto -> begin
    append!( ini.entries, entries )
    ini
end


function verify( ini::InsertInto )
    isempty(ini.entries) && return true
    nvals = length(isempty(ini.columns) ? ini.entries[1] : ini.columns)
    all( nvals .== length.(ini.entries) )
end


insertinto( conn::Conn, asdf::Bool=true ) = ini::InsertInto -> begin
    if !verify(ini)
        @warn "Number of fields in each entry must be the same."
        return
    end

    res = execute( conn, string( ini, ";" ) )
    isempty(ini.returning) && return res
    res |> makeunique! |> (asdf ? DataFrame : columntable)
end
