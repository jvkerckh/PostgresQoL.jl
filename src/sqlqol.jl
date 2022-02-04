abstract type SQLStatement end

const Conn = LibPQ.Connection


dbconnection( dbname::AbstractString; host::AbstractString="localhost", user::AbstractString="postgres", password::AbstractString="postgres" ) =
    string( "host=", host == "localhost" ? "127.0.0.1" : host, " dbname=$dbname user=$user password=$password" ) |> Conn


function makeunique!( v::Vector{T} ) where T <: AbstractString
    vunique = unique(v)
    length(vunique) == length(v) && return v

    for el in vunique
        inds = findall( v .== el )
        
        for ii in 1:(length(inds) - 1)
            v[inds[ii+1]] = string( v[inds[ii+1]], '_', ii )
        end
    end

    v
end

makeunique!( res::LibPQ.Result ) = makeunique!(res.column_names)

makeunique( v::Vector{T} ) where T <: AbstractString =
    deepcopy(v) |> makeunique!


function tableresult( res::LibPQ.Result{false}; df::Bool=true )
    tmpres = deepcopy(res)
    makeunique!(tmpres.column_names)
    res |> (df ? DataFrame : columntable)
end


function dbname( conn::Conn )
    copts = filter( copt -> copt.keyword == "dbname", LibPQ.conninfo(conn) )
    copts[1].val
end


function gettables( conn::Conn )
    # Rework to use QoL functions.
    res = execute( conn, """SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public' AND table_catalog = '$(dbname(conn))';""" ) |> tableresult
    res[:, :table_name] |> Vector{String}
end


function getcolumnnames( conn::Conn, tablename::AbstractString )
    if tablename ∉ gettables(conn)
        @warn "Database does not contain a table '$tablename'."
        return String[]
    end

    # Rework to use QoL functions.
    res = execute( conn, """SELECT column_name FROM information_schema.columns
        WHERE table_catalog = '$(dbname(conn))' AND table_name = '$tablename'
        ORDER BY ordinal_position;""" ) |> tableresult
    res[:, :column_name] |> Vector{String}
end
