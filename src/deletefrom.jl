mutable struct DeleteFrom <: SQLStatement
    name::String
    wherec::SQLCondition
    returning::Vector{String}

    DeleteFrom( name::AbstractString, cond::SQLCondition=nocond ) = new( name, cond, String[] )
end

function Base.show( io::IO, df::DeleteFrom )
    print( io, "DELETE FROM \"", df.name, "\"" )
    isempty(df.wherec) || print( io, "\n    WHERE ", df.wherec )
    isempty(df.returning) || print( io, "\n    RETURNING ", join( df.returning, ", " ) )
end


setreturning!( names::Vector{T} ) where T <: AbstractString =
    dm::Union{InsertInto, Update, DeleteFrom} -> begin
        dm.returning = names |> Vector{String}
        dm
    end
setreturning!( names::Vector{Var} ) = string.(names) |> setreturning!
setreturning!( names::SVar... ) = string.( names |> collect ) |> setreturning!


deletefrom( conn::Conn, asdf::Bool=true ) = df::DeleteFrom -> begin
    res = execute( conn, string( df, ";" ) )
    isempty(df.returning) && return res
    res |> makeunique! |> (asdf ? DataFrame : columntable)
end
