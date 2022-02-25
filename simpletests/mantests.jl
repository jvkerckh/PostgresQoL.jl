if !isdefined( Main, :PostgresQoL )
    include("../src/PostgresQoL.jl")
    using Main.PostgresQoL
end

conn = dbconnection( "mydb", user="juliadev", password="juliadev" )

dbname(conn)
gettables(conn)

DropTable( Var.( conn |> gettables ) ) |> execute(conn)

CreateTable("table1") |>
    addtablecolumn!( "id", "integer", ["PRIMARY KEY"] ) |>
    addtablecolumn!( "var1", "real" ) |>
    addtablecolumn!( "var2", "text" ) |>
    execute(conn)

gettables(conn)
getcolumnnames( conn, "table1" )

CreateTable("weather") |>
    addtablecolumn!( "city", "varchar(80)" ) |>
    addtablecolumn!( "temp_lo", "int" ) |>
    addtablecolumn!( "temp_hi", "int" ) |>
    addtablecolumn!( "prcp", "real" ) |>
    addtablecolumn!( "date", "date" ) |>
    execute(conn)

CreateTable("cities") |>
    addtablecolumn!( "name", "varchar(80)" ) |>
    addtablecolumn!( "location", "point" ) |>
    execute(conn)

InsertInto("weather") |>
    addentries!( ["San Francisco" |> SQLString, 46, 50, .25, "1994-11-27" |> SQLString] ) |>
    execute(conn)

InsertInto("cities") |>
    addentries!( ["San Francisco" |> SQLString, "(-194.0, 53.0)" |> SQLString] ) |>
    execute(conn)

InsertInto("weather", "city", "temp_lo", "temp_hi", "prcp", "date") |>
    addentries!( ["San Francisco" |> SQLString, 43, 57, 0.0, "1994-11-29" |> SQLString] ) |>
    execute(conn)

InsertInto("weather", "date", "city", "temp_hi", "temp_lo") |>
    addentries!( ["'1994-11-29'", "'Hayward'", 54, 37] ) |>
    execute(conn)

Select("weather") |>
    addqueryfield!("*") |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("city") |>
    addqueryfield!( "(temp_hi+temp_lo)/2", "temp_avg" ) |>
    addqueryfield!("date") |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("*") |>
    setwhereclause!( SQLAnd(
        SQLeq( "city", "San Francisco" |> SQLString ),
        SQLgt( "prcp", 0.0 )
    ) ) |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("*") |>
    addorderby!("city") |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("*") |>
    addorderby!("city") |>
    addorderby!("temp_lo") |>
    execute(conn) |> display

Select( "weather", distinct=true ) |>
    addqueryfield!("city") |>
    execute(conn) |> display

Select( "weather", distinct=true ) |>
    addorderby!("city") |>
    addqueryfield!("city") |>
    execute(conn) |> display

jt = JoinTable( "weather", "cities" ) |>
    setjoincondition!( SQLeq( "city", "name" ) )
Select(jt) |>
    addqueryfield!("*") |>
    execute(conn) |> display

jt = JoinTable( "weather", "cities" ) |>
    setjoincondition!( SQLeq( "city", "name" ) )
Select(jt) |>
    addqueryfield!("city") |>
    addqueryfield!("temp_lo") |>
    addqueryfield!("temp_hi") |>
    addqueryfield!("prcp") |>
    addqueryfield!("date") |>
    addqueryfield!("location") |>
    execute(conn) |> display

jt = JoinTable( "weather", "cities" ) |>
    setjoincondition!( SQLeq( Var( "weather", "city" ), Var( "cities", "name" ) ) )
Select(jt) |>
    addqueryfield!(Var( "weather", "city" )) |>
    addqueryfield!(Var( "weather", "temp_lo" )) |>
    addqueryfield!(Var( "weather", "temp_hi" )) |>
    addqueryfield!(Var( "weather", "prcp" )) |>
    addqueryfield!(Var( "weather", "date" )) |>
    addqueryfield!(Var( "cities", "location" )) |>
    execute(conn) |> display

jt = JoinTable( "weather", "cities", :left ) |>
    setjoincondition!( SQLeq( Var( "weather", "city" ), Var( "cities", "name" ) ) )
Select(jt) |>
    addqueryfield!("*") |>
    execute(conn) |> display

jt = JoinTable( "weather", "weather", alias="w1", jalias="w2" ) |>
    setjoincondition!( SQLAnd(
        SQLlt( Var( "w1", "temp_lo" ), Var("w2", "temp_lo" ) ),
        SQLgt( Var( "w1", "temp_hi" ), Var("w2", "temp_hi" ) )
    ) )
Select(jt) |>
    addqueryfield!( Var( "w1", "city" ) ) |>
    addqueryfield!( Var( "w1", "temp_lo" ), "low" ) |>
    addqueryfield!( Var( "w1", "temp_hi" ), "high" ) |>
    addqueryfield!( Var( "w2", "city" ) ) |>
    addqueryfield!( Var( "w2", "temp_lo" ), "low" ) |>
    addqueryfield!( Var( "w2", "temp_hi" ), "high" ) |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("max(temp_lo)") |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("city") |>
    setwhereclause!( SQLeq( "temp_lo",
        string( "(", Select("weather") |> addqueryfield!("max(temp_lo)"), ")" )
    ) ) |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("city") |>
    addqueryfield!("max(temp_lo)") |>
    setgroupby!("city") |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("city") |>
    addqueryfield!("max(temp_lo)") |>
    setgroupby!("city") |>
    sethavingclause!( SQLlt( "max(temp_lo)", 40 ) ) |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("city") |>
    addqueryfield!("max(temp_lo)") |>
    setwhereclause!( SQLlike( "city", "S%" ) ) |>
    setgroupby!("city") |>
    sethavingclause!( SQLlt( "max(temp_lo)", 40 ) ) |>
    execute(conn) |> display

Update("weather") |>
    addcolumnupdate!( "temp_hi", "temp_hi - 2" ) |>
    addcolumnupdate!( "temp_lo", "temp_lo - 2" ) |>
    setwhereclause!( SQLgt( "date", "'1994-11-28'" ) ) |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("*") |>
    execute(conn) |> display

DeleteFrom("weather") |>
    setwhereclause!( SQLeq( "city", "Hayward" |> SQLString ) ) |>
    execute(conn) |> display

Select("weather") |>
    addqueryfield!("*") |>
    execute(conn) |> display

# close(conn)