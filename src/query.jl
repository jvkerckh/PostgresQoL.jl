abstract type SQLQuery <: SQLStatement end

mutable struct Select <: SQLQuery
    isdistinct::Bool
    name::String
    alias::String
    columns::Vector{String}
    aliases::Vector{Var}
    wherec::SQLCondition
    groupby::Vector{Var}
    having::SQLCondition
    orderby::Vector{String}
    asc::Vector{Bool}
    nulllast::Vector{Bool}
    limit::Int
    offset::Int

    Select( name::AbstractString=""; alias::AbstractString="", distinct::Bool=false ) = new( distinct, name, alias, String[], Var[], nocond, Var[], nocond, String[], Bool[], Bool[], -1, 0 )
end

Select( name::Var; alias::AbstractString="", distinct::Bool=false ) = Select( name |> string, alias=alias, distinct=distinct )
Select( jc::Join; alias::AbstractString="", distinct::Bool=false ) = Select( "($jc)", alias=alias, distinct=distinct )
Select( sq::Select, alias::AbstractString; distinct::Bool=false ) = Select( "($sq)", alias=alias, distinct=distinct )

function Base.show( io::IO, sq::Select )
    isempty(sq.columns) && return
    print( io, "SELECT " )
    sq.isdistinct && print( io, "DISTINCT " )
    colstr = map( eachindex(sq.columns) ) do ii
        isempty(sq.aliases[ii]) && return string(sq.columns[ii])
        "$(sq.columns[ii]) AS $(sq.aliases[ii])"
    end
    print( io, join( colstr, ", " ) )

    if !isempty(sq.name)
        print( io, "\n    FROM $(sq.name)" )
        isempty(sq.alias) || print( io, " AS \"$(sq.alias)\"" )
    end

    isempty(sq.wherec) || print( io, "\n    WHERE $(sq.wherec)" )
    isempty(sq.groupby) || print( io, "\n    GROUP BY $(join( sq.groupby, ", " ))" )
    isempty(sq.having) || print( io, "\n    HAVING $(sq.having)" )

    if !isempty(sq.orderby)
        print( io, "\n    ORDER BY " )
        ostr = map( eachindex(sq.orderby) ) do ii
            print( io, sq.orderby[ii], ' ', sq.asc[ii] ? "ASC" : "DESC", " NULLS ", sq.nulllast[ii] ? "LAST" : "FIRST" )
        end
        print( io, join( ostr, ", " ) )
    end
    
    if (sq.limit >= 0) || (sq.offset > 0)
        print( io, "\n   " )
        sq.limit < 0 || print( io, " LIMIT ", sq.limit )
        sq.offset > 0 && print( io, " OFFSET ", sq.offset )
    end
end


addqueryfield!( column::SVar, alias::SVar="" ) = sq::Select -> begin
    push!( sq.columns, column |> string )
    push!( sq.aliases, alias |> Var )
    sq
end


function setwhereclause!( cond::SQLCondition )
    dm::Union{Update, DeleteFrom, Select} -> begin
        dm.wherec = cond
        dm
    end
end


setgroupby!( columns::Vector{Var} ) = sq::Select -> begin
    sq.groupby = columns
    sq
end
setgroupby!( columns::Vector{T} ) where T <: AbstractString = Var.(columns) |> setgroupby!
setgroupby!( columns::SVar... ) = Var.( columns |> collect ) |> setgroupby!


sethavingclause!( cond::SQLCondition ) = sq::Select -> begin
    sq.having = cond
    sq
end


selectquery( conn::Conn, asdf::Bool=true ) = sq::Select -> begin
    res = execute( conn, string( sq, ";" ) )
    res |> makeunique! |> (asdf ? DataFrame : columntable)
end
