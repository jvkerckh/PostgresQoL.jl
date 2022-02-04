mutable struct Update <: SQLStatement
    name::String
    columns::Vector{Var}
    values::Vector
    wherec::SQLCondition
    returning::Vector{String}

    Update( name::AbstractString ) = new( name, Var[], Any[], nocond, String[] )
end

function Base.show( io::IO, up::Update )
    isempty(up.columns) && return
    print( io, "UPDATE \"", up.name, "\"\n    SET ", join( string.( up.columns, " = ", processentry.(up.values) ), ", " ) )
    isempty(up.wherec) || print( io, "\n    WHERE ", up.wherec )
    isempty(up.returning) || print( io, "\n    RETURNING ", join( up.returning, ", " ) )
end


addcolumnupdate!( colname::Var, val ) = up::Update -> begin
    push!( up.columns, colname )
    push!( up.values, val )
    up
end
addcolumnupdate!( colname::AbstractString, val ) = addcolumnupdate!( Var(colname), val )


update( conn::Conn, asdf::Bool=true ) = up::Update -> begin
    res = execute( conn, string( up, ";" ) )
    isempty(up.returning) && return res
    res |> makeunique! |> (asdf ? DataFrame : columntable)
end
