export  Conn,
        execute,
        dbconnection,
        tableresult,
        dbname,
        gettables,
        getcolumnnames


abstract type SQLStatement end

"""
`Conn` is a shorthand for `LibPQ.Connection`, the Julia type that represents a connection to a PostgreSQL database.
"""
const Conn = LibPQ.Connection


function execute( conn::Conn, sqls::SQLStatement; kwargs... )
    tname = typeof(sqls) |> string |> lowercase
    fn = Core.eval( @__MODULE__, tname |> Meta.parse )
    fn( conn, kwargs... )
end


"""
```
dbconnection(
    dbname::AbstractString;
    host::AbstractString="localhost",
    user::AbstractString="postgres",
    password::AbstractString="postgres" )
```
This function creates a connection to a PostgreSQL database with name `dbname`. The database is hosted on the server with address `host`, and connects with the given `user` and `password`.
"""
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


"""
```
tableresult(
    res::LibPQ.Result{false};
    df::Bool=true )
```
This function converts the result `res` of a PostgreSQL query to either a `DataFrame` if `df` is `true`, and to a `NamedTuple` (using the function `columntables` from `Tables.jl`) otherwise.
"""
function tableresult( res::LibPQ.Result{false}; df::Bool=true )
    tmpres = deepcopy(res)
    makeunique!(tmpres.column_names)
    res |> (df ? DataFrame : columntable)
end


"""
```
dbname( conn::Conn )
```
This function returns the name of the database that `conn` is connecting to.
"""
function dbname( conn::Conn )
    copts = filter( copt -> copt.keyword == "dbname", LibPQ.conninfo(conn) )
    copts[1].val
end


"""
```
gettables( conn::Conn )
```
This function returns a vector with the names of all the user-defined tables in the database that `conn` is connecting to. System tables are left out of this list.
"""
function gettables( conn::Conn )
    # Rework to use QoL functions.
    # res = execute( conn, """SELECT table_name FROM information_schema.tables
    #     WHERE table_schema = 'public' AND table_catalog = '$(dbname(conn))';""" ) |> tableresult
    Select( "information_schema.tables" ) |>
        addqueryfield!( "table_name" ) |>
        setwhereclause!( SQLAnd(
            SQLeq( "table_schema", "public" |> SQLString ),
            SQLeq( "table_catalog", dbname(conn) |> SQLString ) ) ) |>
        selectquery(conn) |> tableresult
    res[:, :table_name] |> Vector{String}
end


"""
```
getcolumnnames(
    conn::Conn,
    tablename::AbstractString )
```
This function returns the names of the columns in the table with name `tablename` of the database that `conn` is connecting to. If the table is not a user-defined table or doesn't exist, this function gives a warning returns an empty vector.
"""
function getcolumnnames( conn::Conn, tablename::AbstractString )
    if tablename ∉ gettables(conn)
        @warn "Database does not contain a table '$tablename'."
        return String[]
    end

    # Rework to use QoL functions.
    # res = execute( conn, """SELECT column_name FROM information_schema.columns
    #     WHERE table_catalog = '$(dbname(conn))' AND table_name = '$tablename'
    #     ORDER BY ordinal_position;""" ) |> tableresult
    Select( "information_schema.columns" ) |>
        addqueryfield!( "column_name" ) |>
        setwhereclause!( SQLAnd(
            SQLeq( "table_catalog", "dbname(conn)" |> SQLString ),
            SQLeq( "table_name", "tablename" |> SQLString ) ) ) |>
        addorderby!( "ordinal_position" ) |>
        selectquery(conn) |> tableresult
    res[:, :column_name] |> Vector{String}
end
