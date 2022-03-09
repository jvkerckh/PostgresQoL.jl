export  SQLAnd, SQLOr, SQLNot


processentry( x ) = "$x"
processentry( x::Vector ) = string( '[', join( processentry.(x), ", " ), ']' )
processentry( x::Missing ) = "NULL"
processentry( x::Dict ) = json(x) |> processentry


sqlcops = Dict(
    :lt => (2, ["<"], :geq),
    :gt => (2, [">"], :leq),
    :leq => (2, ["<="], :gt),
    :geq => (2, [">="], :lt),
    :eq => (2, ["="], :neq),
    :neq => (2, ["<>"], :eq),
    :in => (2, ["IN"], :nin),
    :nin => (2, ["NOT IN"], :in),
    :like => (2, ["LIKE"], :nlike),
    :nlike => (2, ["NOT LIKE"], :like),
    :between => (3, ["BETWEEN", "AND"], :nbetween),
    :nbetween => (3, ["NOT BETWEEN", "AND"], :between),
    :betweensym => (3, ["BETWEEN SYMMETRIC", "AND"], :nbetweensym),
    :nbetweensym => (3, ["NOT BETWEEN SYMMETRIC", "AND"], :betweensym),
    :distinct => (2, ["IS DISTINCT FROM"], :ndistinct),
    :ndistinct => (2, ["IS NOT DISTINCT FROM"], :distinct),
    :null => (1, ["IS NULL"], :nnull),
    :nnull => (1, ["IS NOT NULL"], :null),
    :true => (1, ["IS TRUE"], :ntrue),
    :ntrue => (1, ["IS NOT TRUE"], :true),
    :false => (1, ["IS FALSE"], :nfalse),
    :nfalse => (1, ["IS NOT FALSE"], :false),
    :unknown => (1, ["IS UNKNOWN"], :nunknown),
    :nunknown => (1, ["IS NOT UNKNOWN"], :unknown)
)


abstract type SQLCondition end

struct NoCondition <: SQLCondition end
"""
`nocond` is the empty SQL condition. This will not render if part of a clause.
"""
const nocond = NoCondition()
Base.isempty(cond::SQLCondition) = cond isa NoCondition

mutable struct CompoundCondition <: SQLCondition
    lop::Symbol
    conds::Vector{SQLCondition}

    function CompoundCondition( lop, conds::Vector{T} ) where T <: SQLCondition
        lop ∈ [:and, :or, :not] || @error( "Unknown logical operator, only AND, OR, and NOT allowed." )
        length(conds) == 0 && @error( "At least one SQL condition must be given." )

        if lop === :not
            length(conds) == 1 || @error( "Exactly one SQL must be given with NOT operator." )
            return new( :not, deepcopy(conds) )
        end

        length(conds) == 1 && return conds[1]
        new( lop, deepcopy(conds) )
    end

    CompoundCondition( lop::Symbol, conds::SQLCondition... ) = CompoundCondition( lop, conds |> collect )
end

function Base.show( io::IO, cc::CompoundCondition )
    if cc.lop === :not
        print( io, "NOT ($(cc.conds[1]))" )
        return
    end

    cstrs = map( cc.conds ) do cond
        cond isa CompoundCondition ? "($cond)" : "$cond"
    end
    print( io, join( cstrs, " $(string(cc.lop) |> uppercase) " ))
end

"""
```
SQLAnd( conds::Vector{T} ) where T <: SQLCondition
SQLAnd( conds::SQLCondition... )
```
This function creates an SQL condition that concatenates the SQL conditions in `conds` with the `AND` operator.
"""
SQLAnd( conds::Vector{T} ) where T <: SQLCondition = CompoundCondition( :and, conds )
SQLAnd( conds::SQLCondition... ) = CompoundCondition( :and, conds... )
"""
```
SQLOr( conds::Vector{T} ) where T <: SQLCondition
SQLOr( conds::SQLCondition... )
```
This function creates an SQL condition that concatenates the SQL conditions in `conds` with the `OR` operator.
"""
SQLOr( conds::Vector{T} ) where T <: SQLCondition = CompoundCondition( :or, conds )
SQLOr( conds::SQLCondition... ) = CompoundCondition( :or, conds... )
"""
```
SQLNot( cond::CompoundCondition )
SQLNot( cond::BaseCondition )
```
This function creates an SQL condition that is the logical `NOT` of the SQL condition in `cond`. If a basic SQL condition is passed as argument, it creates a new basic condition with the inverse of the operator.
"""
SQLNot( cond::CompoundCondition ) = CompoundCondition( :not, [cond] )


mutable struct BaseCondition <: SQLCondition
    cop::Symbol
    args::Vector{String}

    function BaseCondition( cop::Symbol, args::Vector )
        haskey( sqlcops, cop ) || @error "Unknown comparison operator."
        nargs = length(args)
        rargs = sqlcops[cop][1]
        if cop ∈ [:in, :nin]
            nargs >= rargs || @error "Incorrect number of arguments, at least $rargs arguments required."
        else
            nargs == rargs || @error "Incorrect number of arguments, $rargs arguments required."
        end
        new( cop, processentry.(args) )
    end

    BaseCondition( cop::Symbol, args... ) = BaseCondition( cop, args |> collect )
end

function Base.show( io::IO, bc::BaseCondition )
    nargs = length(bc.args)
    cparts = fill( "", nargs == 1 ? 2 : 2*nargs - 1 )
    cparts[1:2:end] = bc.args
    cparts[2:2:end] = sqlcops[bc.cop][2]
    bc.cop ∈ [:in, :nin] && (cparts[3] = amendarg( cparts[3] ))
    print( io, join( cparts, " " ) )
end

amendarg( arg::String ) =  string( '(', arg[(endswith( arg, ";" ) ? 1 : 2):(end-1)], ')' )
 

SQLNot( cond::BaseCondition ) = BaseCondition( sqlcops[cond.cop][3], cond.args... )


for cop in filter( cop -> sqlcops[cop][1] == 1, keys(sqlcops) |> collect )
    etype = cop ∈ [:null, :nnull] ? Union{Real, SVar, SQLString} : Union{Bool, SVar, SQLCondition, SQLString}
    Core.eval( @__MODULE__, "export SQL$cop" |> Meta.parse )
    Core.eval( @__MODULE__, """\"\"\"
    ```
    SQL$cop( arg::$etype )
    ```
    This function creates a SQL condition of type `<arg> $(sqlcops[cop][2][1])`.
    \"\"\"
    SQL$cop( arg::$etype ) = BaseCondition( :$cop, arg )""" |> Meta.parse )
end

for cop in filter( cop -> sqlcops[cop][1] == 2, keys(sqlcops) |> collect )
    etype = Union{Real, SVar, SQLString}
    Core.eval( @__MODULE__, "export SQL$cop" |> Meta.parse )

    if cop ∈ [:in, :nin]
        Core.eval( @__MODULE__, """\"\"\"
        ```
        SQL$cop(
            larg::$etype,
            rarg::Vector{T}
        ) where T <: $etype
        SQL$cop(
            larg::$etype,
            rarg::SQLStatement )
        ```
        This function creates a SQL condition of type `<larg> $(sqlcops[cop][2][1]) <rarg>`.
        \"\"\"
        SQL$cop( larg::$etype, rarg::Vector{T} ) where T <: $etype = BaseCondition( :$cop, larg, rarg )""" |> Meta.parse )
        Core.eval( @__MODULE__, """SQL$cop( larg::$etype, rarg::SQLStatement ) = BaseCondition( :$cop, larg, rarg )""" |> Meta.parse )
    elseif cop ∈ [:like, :nlike]
        Core.eval( @__MODULE__, """\"\"\"
        ```
        SQL$cop(
            larg::$etype,
            rarg::Union{AbstractString, SQLString} )
        ```
        This function creates a SQL condition of type `<larg> $(sqlcops[cop][2][1]) <rarg>`.
        \"\"\"
        SQL$cop( larg::$etype, rarg::Union{AbstractString, SQLString} ) = BaseCondition( :$cop, larg, rarg |> SQLString )""" |> Meta.parse )
    else
        Core.eval( @__MODULE__, """\"\"\"
        ```
        SQL$cop(
            larg::$etype,
            rarg::$etype )
        ```
        This function creates a SQL condition of type `<larg> $(sqlcops[cop][2][1]) <rarg>`.
        \"\"\"
        SQL$cop( larg::$etype, rarg::$etype ) = BaseCondition( :$cop, larg, rarg )""" |> Meta.parse )
    end
end

for cop in filter( cop -> sqlcops[cop][1] == 3, keys(sqlcops) |> collect )
    etype = Union{Real, SVar, SQLString}
    Core.eval( @__MODULE__, "export SQL$cop" |> Meta.parse )
    Core.eval( @__MODULE__, """\"\"\"
    ```
    SQL$cop(
        carg::$etype,
        larg::$etype,
        rarg::$etype )
    ```
    This function creates a SQL condition of type `<carg> $(sqlcops[cop][2][1]) <larg> $(sqlcops[cop][2][2]) <rarg>`.
    \"\"\"
    SQL$cop( carg::$etype, larg::$etype, rarg::$etype ) = BaseCondition( :$cop, carg, larg, rarg )""" |> Meta.parse )
end
