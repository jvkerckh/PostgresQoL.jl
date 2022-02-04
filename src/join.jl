mutable struct Join <: SQLStatement
    name::String
    alias::Var
    jtype::Symbol
    jname::Var
    jalias::Var
    jctype::Symbol
    jcols::Vector{Var}
    jcond::SQLCondition

    function Join( name::Union{SVar, Join}, jname::SVar, jtype::Symbol=:inner; alias::SVar="", jalias::SVar="" )
        jtype ∈ [:cross, :inner, :left, :right, :full] || @error("Unknown join type, must be :cross, :inner, :left, :right, or :full.")
        new( name |> string, alias |> Var, jtype, jname |> Var, jalias |> Var, :none, Var[], nocond )
    end
end

Join( jname::SVar, jtype::Symbol=:inner; jalias::SVar="" ) = jc::Join -> begin
    Join( jc |> string, jname, jtype, jalias=jalias )
end

function Base.show( io::IO, jc::Join )
    print( io, "$(jc.name) " )
    isempty(jc.alias) || print( io, "$(jc.alias) " )
    jc.jctype === :natural && print( io, "NATURAL " )
    print( io, "$(string(jc.jtype) |> uppercase) JOIN $(jc.jname)" )
    isempty(jc.jalias) || print( io, " $(jc.jalias)" )

    if jc.jctype === :using
        print( io, " USING ($(join( string.(jc.jcols), ", " )))" )
    elseif jc.jctype === :on
        print( io, " ON $(jc.jcond)" )
    end
end


function setnojoincondition!( jc::Join )
    jc.jctype = :none
    jc
end


function setnaturaljoin!( jc::Join )
    jc.jctype = :natural
    jc
end


setusingcolumns!( columns::Vector{Var} ) = jc::Join -> begin
    isempty(columns) && return jc
    jc.jctype = :using
    jc.jcols = columns
    jc
end
setusingcolumns!( columns::Vector{T} ) where T <: AbstractString = Var.(columns) |> setusingcolumns!
setusingcolumns!( columns::SVar... ) = Var.( columns |> collect ) |> setusingcolumns!


setjoincondition!( cond::SQLCondition ) = jc::Join -> begin
    if cond === nocond
        jc.jctype = :none
        return jc
    end

    jc.jctype = :on
    jc.jcond = cond
    jc
end
