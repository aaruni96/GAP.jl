## dealing with GAP packages

"""
    LoadPackageAndExposeGlobals(package::String, mod::String; all_globals::Bool = false)
    LoadPackageAndExposeGlobals(package::String, mod::Module = Main; all_globals::Bool = false, overwrite::Bool = false)

`LoadPackageAndExposeGlobals` loads `package` into GAP via `LoadPackage`,
and stores all newly defined GAP globals as globals in the module `mod`. If `mod` is
a string, the function creates a new module, if `mod` is a Module, it uses `mod` directly.

The function is intended to be used for creating mock modules for GAP packages.
If you load the package `CAP` via

    LoadPackageAndExposeGlobals( "CAP", "CAP" )

you can use CAP commands via

    CAP.PreCompose( a, b )

If `overwrite` is true, Symbols already in the `Main` module will be overloaded.
Be aware that this flag only works in `Main`.

"""
function LoadPackageAndExposeGlobals(
    package::String,
    mod::String;
    all_globals::Bool = false,
)
    mod_sym = Symbol(mod)
    Base.MainInclude.eval(:(module $(mod_sym)
    import GAP
    end))
    ## Adds the new module to the Main module, so it is directly accessible in the julia REPL
    mod_mod = Base.MainInclude.eval(:(Main.$(mod_sym)))

    ## We need to call `invokelatest` as the module `mod_mod` was only created during the
    ## call of this function in a different module, so its world age is higher than the
    ## function calls world age.
    Base.invokelatest(
        LoadPackageAndExposeGlobals,
        package,
        mod_mod;
        all_globals = all_globals,
    )
end

function LoadPackageAndExposeGlobals(
    package::String,
    mod::Module;
    all_globals::Bool = false,
    overwrite::Bool = false,
)
    current_gvar_list = nothing
    if !all_globals
        current_gvar_list = Globals.ShallowCopy(Globals.NamesGVars())
    end
    load_package = EvalString("LoadPackage(\"$package\")")
    if load_package == Globals.fail
        error("cannot load package $package")
    end
    new_gvar_list = Globals.NamesGVars()
    if !all_globals
        new_gvar_list = Globals.Difference(new_gvar_list, current_gvar_list)
    end
    new_symbols = gap_to_julia(Array{Symbol,1}, new_gvar_list)
    for sym in new_symbols
        if overwrite || !isdefined(mod, sym)
            try
                mod.eval(:($(sym) = GAP.Globals.$(sym)))
            catch
            end
        end
    end
end

export LoadPackageAndExposeGlobals


module Packages

import ...GAP: Globals, julia_to_gap, GAPROOT

"""
    load(desc)

TODO: write text, link to GAP's LoadPackage

TODO: support version qualifier?
"""
function load(desc::String)
    return Globals.LoadPackage(julia_to_gap(desc), false)
    # TODO: can we provide more information in case of a failure?
    # GAP unfortunately only gives us info messages...
end

"""
    install(desc)

TODO: copy text from <https://gap-packages.github.io/PackageManager/doc/chap2.html> resp.
link to that
"""
function install(desc::String; interactive::Bool = true, pkgdir::AbstractString = GAPROOT * "/pkg")
    res = load("PackageManager")
    @assert res
    # FIXME: crude hack to allow PackageManager 1.0 shipped with GAP
    # 4.11.0 to work with out of tree builds. For a proper fix, see
    # <https://github.com/gap-packages/PackageManager/pull/55>.
    Globals.PKGMAN_BuildPackagesScript = julia_to_gap(GAPROOT * "/bin/BuildPackages.sh")

    # point PackageManager to our internal pkg dir
    Globals.PKGMAN_CustomPackageDir = julia_to_gap(pkgdir)

    return Globals.InstallPackage(julia_to_gap(desc), interactive)
end

"""
    update(desc)

TODO: copy text from <https://gap-packages.github.io/PackageManager/doc/chap2.html> resp.
link to that
"""
function update(desc::String; interactive::Bool = true, pkgdir::AbstractString = GAPROOT * "/pkg")
    res = load("PackageManager")
    @assert res

    # point PackageManager to our internal pkg dir
    Globals.PKGMAN_CustomPackageDir = julia_to_gap(pkgdir)

    return Globals.UpdatePackage(julia_to_gap(desc), interactive)
end

"""
    remove(desc)

TODO: copy text from <https://gap-packages.github.io/PackageManager/doc/chap2.html> resp.
link to that
"""
function remove(desc::String; interactive::Bool = true, pkgdir::AbstractString = GAPROOT * "/pkg")
    res = load("PackageManager")
    @assert res

    # point PackageManager to our internal pkg dir
    Globals.PKGMAN_CustomPackageDir = julia_to_gap(pkgdir)

    return Globals.RemovePackage(julia_to_gap(desc), interactive)
end

end
