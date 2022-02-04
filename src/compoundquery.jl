struct CompoundQuery <: SQLQuery
    larg::String
    rarg::String
    cop::Symbol
    isall::Bool
    orderby::Vector{Var}
    asc::Vector{Bool}
    nulllast::Vector{Bool}
    limit::Int
    offset::Int

    CompoundQuery( larg::AbstractString, rarg::AbstractString, cop::Symbol, isall::Bool ) = new( larg, rarg, cop, isall, Var[], Bool[], Bool[], -1, 0 )
end

function Base.show( io::IO, cq::CompoundQuery )
    print( io, "(", cq.larg, ") ", uppercase(cq.cop |> string), " " )
    cq.isall && print( io, "ALL " )
    print( io, "(", cq.rarg, ")" )

    if !isempty(cq.orderby)
        print( io, "\n    ORDER BY " )
        ostr = map( eachindex(cq.orderby) ) do ii
            print( io, cq.orderby[ii], ' ', cq.asc[ii] ? "ASC" : "DESC", " NULLS ", cq.nulllast[ii] ? "LAST" : "FIRST" )
        end
        print( io, join( ostr, ", " ) )
    end

    if (cq.limit >= 0) || (cq.offset > 0)
        print( io, "\n   " )
        cq.limit < 0 || print( io, " LIMIT ", cq.limit )
        cq.offset > 0 && print( io, " OFFSET ", cq.offset )
    end
end


for cop in [:union, :intersect, :except]
    Core.eval( @__MODULE__, """query$cop( larg::Union{Select, CompoundQuery}, rarg::Union{Select, CompoundQuery}, isall::Bool=false ) = CompoundQuery( larg |> string, rarg |> string, :$cop, isall )""" |> Meta.parse )
end


function addorderby!( column::AbstractString; asc::Bool=true, nullorder::Symbol=:default )
    sq::SQLQuery -> begin
        if nullorder ∉ [:first, :last, :default]
            @warn "Unknown nullorder, must be one of :first, :last, or :default"
            return sq
        end

        push!( sq.orderby, sq isa Select ? column : Var(column) )
        push!( sq.asc, asc )
        push!( sq.nulllast, nullorder === :default ? asc : nullorder === :first )
        sq
    end
end

addorderby!( column::Var; asc::Bool=true, nullorder::Symbol=:default ) = addorderby!( column |> Var, asc=asc, nullorder=nullorder )


compoundquery( conn::Conn, asdf::Bool=true ) = cq::CompoundQuery -> begin
    res = execute( conn, string( cq, ";" ) )
    res |> makeunique! |> (asdf ? DataFrame : columntable)
end


function clearlimit!( sq::SQLQuery )
    sq.limit = -1
    sq
end


setlimit!( limit::Int ) = sq::SQLQuery -> begin
    limit < 0 && return clearlimit!(sq)
    sq.limit = limit
    sq
end


function clearoffset!( sq::SQLQuery )
    sq.offset = 0
    sq
end


setoffset!( offset::Int ) = sq::SQLQuery -> begin
    offset > 0 || return clearoffset!(sq)
    sq.offset = offset
    sq
end
