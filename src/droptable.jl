mutable struct DropTable <: SQLStatement
    names::Vector{String}

    DropTable( names::Vector{T} ) where T <: AbstractString = new(Vector{String}(names))
end

DropTable( names::AbstractString... ) = collect(names) |> DropTable

function Base.show( io::IO, dt::DropTable )
    isempty(dt.names) && return
    print( io, "DROP TABLE ", join( unique(dt.names), ", " ) )
end


addtables!( names::Vector{T} ) where T <: AbstractString = dt::DropTable -> begin
    append!( dt.names, names )
    dt
end
addtables!( names::AbstractString... ) = collect(names) |> addtables!


function sanitise!( dt::DropTable, conn::Conn )
    dbtables = gettables(conn)
    filter!( name -> name ∈ dbtables, dt.names )
    unique!(dt.names)
end


droptable( conn::Conn; muteerror::Bool=true ) = dt::DropTable -> begin
    muteerror && sanitise!( dt, conn )
    execute( conn, string( dt, ";" ) )
end
